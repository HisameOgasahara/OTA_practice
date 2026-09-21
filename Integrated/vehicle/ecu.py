"""Persist and observe the simulated vehicle."""
import json
from pathlib import Path


def read_state(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))


def write_state(path, state):
    path = Path(path)
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(state, indent=2), encoding='utf-8')
    temporary.replace(path)


def observe(state):
    firmware = state['slots'][state['active_slot']]
    return dict(active_slot=state['active_slot'], version=firmware['version'],
                behavior=firmware['behavior'],
                headlamp='OFF' if firmware['behavior'] == 'FORCE_HEADLAMP_OFF' else 'ON')
