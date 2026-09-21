#!/usr/bin/env python3
import json, urllib.request
from pathlib import Path
root=Path(__file__).resolve().parents[1]
conf=json.loads((root/'common'/'server_config.json').read_text())
base_url=f"http://{conf['pc_server_ip']}:8000"
print('=== Basic OTA Client ===')
print('Server:', base_url)
try:
    manifest=json.loads(urllib.request.urlopen(base_url+'/manifest.json', timeout=5).read().decode())
    firmware=json.loads(urllib.request.urlopen(base_url+'/'+manifest['firmware'], timeout=5).read().decode())
except Exception as e:
    print('[ERROR] HTTP download failed:', e)
    print('Check: PC server running / PC IP / Windows Firewall / same Wi-Fi')
    raise SystemExit(1)
print('Downloaded release :', manifest['version'])
print('Firmware behavior  :', firmware['behavior'])
state=root/'day2_basic_ota'/'vehicle'/'state.json'
state.write_text(json.dumps({'version':firmware['version'],'behavior':firmware['behavior']}, indent=2), encoding='utf-8')
print('Install result     : ACCEPTED')
print('Security check     : NONE')
