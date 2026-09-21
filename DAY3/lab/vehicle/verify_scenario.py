"""Run the textbook client and verify both its decision and persisted ECU state."""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
LAB = ROOT / 'day3_secure_ota'
STATE = LAB / 'vehicle/state.json'
CONFIG = json.loads((ROOT / 'common/server_config.json').read_text())


def run_script(relative):
    result = subprocess.run([sys.executable, str(LAB / relative)],
                            capture_output=True, text=True, timeout=CONFIG['remote_command_timeout_seconds'])
    print(result.stdout, end='', flush=True)
    if result.stderr:
        print(result.stderr, end='', file=sys.stderr, flush=True)
    return result


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def main():
    name = sys.argv[1]
    if name == 'reset':
        require(run_script('reset_day3.py').returncode == 0, 'Reset failed')
        state = json.loads(STATE.read_text())
        require(state == {'active_slot': 'slot_A', 'slots': {
            'slot_A': {'version': '1.0', 'behavior': 'NORMAL', 'health': 'GOOD'},
            'slot_B': None}}, 'Initial state mismatch')
    else:
        cases = json.loads((ROOT / 'scenarios.json').read_text(encoding='utf-8'))
        case = next(case for case in cases if case['id'] == name)
        before = STATE.read_bytes()
        old_state = json.loads(before)
        result = run_script('secure_ota_client.py')
        require(result.returncode == case['exit_code'],
                f"Unexpected exit code: {result.returncode}")
        for marker in case['markers']:
            require(marker in result.stdout, f'Missing result: {marker}')
        state = json.loads(STATE.read_text())
        active = state['slots'][state['active_slot']]
        require(state['active_slot'] == 'slot_B' and active['version'] == '2.0'
                and active['behavior'] == 'NORMAL' and active['health'] == 'GOOD',
                'Active slot must remain healthy v2.0 in slot_B')
        if name in ('firmware', 'manifest', 'rollback'):
            require(STATE.read_bytes() == before, 'Rejected update changed vehicle state')
        elif name == 'normal':
            require(state['slots']['slot_A'] == old_state['slots']['slot_A'],
                    'Normal update damaged the previous slot')
        elif name == 'recovery':
            require(state['slots']['slot_B'] == old_state['slots']['slot_B'],
                    'Recovery changed the active firmware')
            inactive = state['slots']['slot_A']
            require(inactive['version'] == '3.0' and inactive['health'] == 'FAIL',
                    'Failed candidate not present in inactive slot')
        (ROOT / f'{name}.result.json').write_text(json.dumps({
            'scenario': name, 'result': 'PASSED', 'client_exit_code': result.returncode,
            'state': state}, indent=2), encoding='utf-8')
    require(run_script('vehicle/status.py').returncode == 0, 'Status failed')
    ecu = run_script('vehicle/ecu_run.py')
    require(ecu.returncode == 0 and 'Headlamp command : ON' in ecu.stdout,
            'Headlamp must remain ON')
    print(f'[PASS] {name}: decision, vehicle state and headlamp verified')


if __name__ == '__main__':
    main()
