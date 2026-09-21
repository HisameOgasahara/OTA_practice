"""Run one OTA attempt without access to scenario expectations."""
import argparse
import json
import urllib.request
from pathlib import Path
from ecu import read_state, observe
from installation import install
from verification import Rejected, verify_signature, verify_payload, verify_version

ROOT = Path(__file__).resolve().parents[1]


def update(policy, state_path, config):
    base = f"http://{config['pc_server_ip']}:{config['port']}"
    # Deliberately limit transport to the lab repository files, even in basic mode.
    def download(name):
        if name not in ('manifest.json', 'firmware.json', 'signature.sig'):
            raise ValueError('Unexpected repository filename')
        with urllib.request.urlopen(base + '/' + name, timeout=config['http_timeout_seconds']) as response:
            return response.read()

    manifest_bytes = download('manifest.json')
    if policy == 'secure':
        verify_signature(manifest_bytes, download('signature.sig'),
                         Path(__file__).parent / 'keys/oem_public_key.pem',
                         config['remote_command_timeout_seconds'])
    manifest = json.loads(manifest_bytes)
    payload = download(manifest['firmware'])
    state = read_state(state_path)
    if policy == 'secure':
        verify_payload(manifest, payload)
        verify_version(manifest, state['slots'][state['active_slot']])
    else:
        print('Security check: NONE')
    firmware = json.loads(payload)
    return install(state_path, state, firmware, policy)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--policy', choices=('basic', 'secure'), required=True)
    args = parser.parse_args()
    config = json.loads((ROOT / 'server_config.json').read_text(encoding='utf-8'))
    state_path = ROOT / 'state.json'
    try:
        decision = update(args.policy, state_path, config)
    except Rejected as error:
        decision = str(error)
    result = dict(decision=decision, state=observe(read_state(state_path)))
    print('CLIENT_JSON=' + json.dumps(result))
    return 0 if decision == 'ACCEPTED' else 1


if __name__ == '__main__':
    raise SystemExit(main())
