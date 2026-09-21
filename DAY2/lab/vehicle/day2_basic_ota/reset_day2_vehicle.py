#!/usr/bin/env python3
import json
from pathlib import Path
p=Path(__file__).parent/'vehicle'/'state.json'
p.write_text(json.dumps({'version':'1.0','behavior':'NORMAL'}, indent=2), encoding='utf-8')
print('Day 2 vehicle reset complete: vehicle=v1.0 NORMAL')
