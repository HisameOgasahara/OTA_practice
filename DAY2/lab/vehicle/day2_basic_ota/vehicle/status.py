#!/usr/bin/env python3
import json
from pathlib import Path
s=json.loads((Path(__file__).with_name('state.json')).read_text())
print('=== Virtual BCM_HEADLAMP Status ===')
print('Version  :', s['version'])
print('Behavior :', s['behavior'])
