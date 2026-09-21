"""Check the client's decision against independently persisted vehicle state."""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'vehicle'))
from ecu import read_state, write_state, observe


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def main():
    cases = json.loads((ROOT / 'scenarios/scenarios.json').read_text(encoding='utf-8'))
    case = next(item for item in cases if item['id'] == sys.argv[1])
    state_path = ROOT / 'state.json'
    if case['reset'] is not None:
        write_state(state_path, case['reset'])
        print('[RESET] ' + json.dumps(observe(case['reset'])), flush=True)
    before = state_path.read_bytes()
    old = read_state(state_path)
    config = json.loads((ROOT / 'server_config.json').read_text(encoding='utf-8'))
    client = subprocess.run([sys.executable, str(ROOT / 'vehicle/ota_client.py'),
                             '--policy', case['policy']], capture_output=True, text=True,
                            timeout=config['remote_command_timeout_seconds'])
    print(client.stdout, end='')
    if client.stderr:
        print(client.stderr, file=sys.stderr, end='')
    lines = [line[12:] for line in client.stdout.splitlines() if line.startswith('CLIENT_JSON=')]
    require(len(lines) == 1, 'Client failed without an OTA decision')
    actual = json.loads(lines[0])
    expected = case['expected']
    require(actual['decision'] == expected['decision'], 'Unexpected OTA decision')
    require(client.returncode == (0 if expected['decision'] == 'ACCEPTED' else 1), 'Unexpected client exit')
    state = read_state(state_path)
    observed = observe(state)
    require(actual['state'] == observed, 'Reported and persisted states differ')
    for name in ('version', 'behavior', 'active_slot'):
        require(observed[name] == expected[name], f'Unexpected {name}')
    require(observed['headlamp'] == ('OFF' if expected['behavior'] == 'FORCE_HEADLAMP_OFF' else 'ON'), 'Unexpected headlamp')
    if expected['unchanged']:
        require(state_path.read_bytes() == before, 'Rejected update changed state')
    if case['policy'] == 'secure':
        old_slot = old['active_slot']
        require(state['slots'][old_slot] == old['slots'][old_slot], 'Previous active firmware was changed')
    if 'inactive' in expected:
        inactive = 'slot_B' if state['active_slot'] == 'slot_A' else 'slot_A'
        for key, value in expected['inactive'].items():
            require(state['slots'][inactive][key] == value, 'Failed candidate missing')
    result = dict(scenario=case['id'], result='PASSED', decision=actual['decision'],
                  reset=case['reset'] is not None, before=json.loads(before), after=state,
                  headlamp=observed['headlamp'])
    (ROOT / (case['id'] + '.result.json')).write_text(json.dumps(result, indent=2), encoding='utf-8')
    print('RESULT_JSON=' + json.dumps(result))


if __name__ == '__main__':
    main()
