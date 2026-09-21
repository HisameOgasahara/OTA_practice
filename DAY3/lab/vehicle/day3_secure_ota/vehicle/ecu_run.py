#!/usr/bin/env python3
import json
from pathlib import Path
s=json.loads((Path(__file__).with_name('state.json')).read_text())
fw=s['slots'][s['active_slot']]
cmd='OFF' if fw['behavior']=='FORCE_HEADLAMP_OFF' else 'ON'
print('=== BCM_HEADLAMP Run ===')
print('Active slot      :', s['active_slot'])
print('Firmware version :', fw['version'])
print('Behavior         :', fw['behavior'])
print('Headlamp command :', cmd)
print('Result           :', 'NORMAL' if cmd=='ON' else 'SECURITY IMPACT')
