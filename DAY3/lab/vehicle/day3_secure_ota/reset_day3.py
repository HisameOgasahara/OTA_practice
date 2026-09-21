#!/usr/bin/env python3
import json
from pathlib import Path
state={'active_slot':'slot_A','slots':{'slot_A':{'version':'1.0','behavior':'NORMAL','health':'GOOD'},'slot_B':None}}
p=Path(__file__).parent/'vehicle'/'state.json'
p.write_text(json.dumps(state, indent=2), encoding='utf-8')
print('Day 3 vehicle reset complete: active=slot_A v1.0')
