#!/usr/bin/env python3
import json
from pathlib import Path
s=json.loads((Path(__file__).with_name('state.json')).read_text())
cmd='OFF' if s['behavior']=='FORCE_HEADLAMP_OFF' else 'ON'
print('=== BCM_HEADLAMP Run ===')
print('Firmware version :', s['version'])
print('Behavior         :', s['behavior'])
print('Headlamp command :', cmd)
if cmd=='OFF' and s['behavior']=='FORCE_HEADLAMP_OFF':
    print('Result           : SECURITY IMPACT - abnormal lamp control')
else:
    print('Result           : NORMAL')
