#!/usr/bin/env python3
import json
from pathlib import Path
s=json.loads((Path(__file__).with_name('state.json')).read_text())
print('=== Secure Virtual ECU Status ===')
print('Active slot:', s['active_slot'])
for k in ['slot_A','slot_B']:
    v=s['slots'].get(k)
    if v: print(f"{k}: v{v['version']} / {v['behavior']} / health={v['health']}")
    else: print(f'{k}: EMPTY')
