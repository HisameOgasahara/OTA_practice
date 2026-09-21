#!/usr/bin/env python3
import json, urllib.request, hashlib, tempfile, subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[1]
conf=json.loads((root/'common'/'server_config.json').read_text())
base_url=f"http://{conf['pc_server_ip']}:{conf['port']}"
print('=== Secure OTA Client ===')
print('Server:', base_url)
try:
    manifest_bytes=urllib.request.urlopen(base_url+'/manifest.json', timeout=conf['http_timeout_seconds']).read()
    signature=urllib.request.urlopen(base_url+'/signature.sig', timeout=conf['http_timeout_seconds']).read()
    manifest=json.loads(manifest_bytes.decode())
    firmware_bytes=urllib.request.urlopen(base_url+'/'+manifest['firmware'], timeout=conf['http_timeout_seconds']).read()
    firmware=json.loads(firmware_bytes.decode())
except Exception as e:
    print('[ERROR] HTTP download failed:', e)
    print('Check: PC server running / PC IP / Windows Firewall / same Wi-Fi')
    raise SystemExit(1)

with tempfile.TemporaryDirectory() as td:
    td=Path(td)
    mp=td/'manifest.json'; sp=td/'signature.sig'
    mp.write_bytes(manifest_bytes); sp.write_bytes(signature)
    pub=root/'day3_secure_ota'/'keys'/'oem_public_key.pem'
    r=subprocess.run(['openssl','dgst','-sha256','-verify',str(pub),'-signature',str(sp),str(mp)],capture_output=True,text=True)
    if r.returncode!=0:
        print('Manifest signature : FAIL')
        print('Update             : REJECTED')
        raise SystemExit(1)
print('Manifest signature : PASS')

actual=hashlib.sha256(firmware_bytes).hexdigest()
if actual.lower()!=manifest['sha256'].lower():
    print('Firmware SHA-256   : FAIL')
    print('Update             : REJECTED')
    raise SystemExit(1)
print('Firmware SHA-256   : PASS')

state_path=root/'day3_secure_ota'/'vehicle'/'state.json'
state=json.loads(state_path.read_text())
active=state['active_slot']; current=state['slots'][active]
try:
    curv=tuple(map(int,current['version'].split('.'))); newv=tuple(map(int,manifest['version'].split('.')))
except Exception:
    print('Version policy     : FAIL (invalid version)'); raise SystemExit(1)
if newv<=curv:
    print(f"Version policy     : FAIL (current={current['version']}, new={manifest['version']})")
    print('Anti-Rollback      : REJECT')
    raise SystemExit(1)
print(f"Version policy     : PASS (current={current['version']}, new={manifest['version']})")

inactive='slot_B' if active=='slot_A' else 'slot_A'
state['slots'][inactive]=firmware
print('Install            :', inactive)
if firmware.get('health')!='GOOD':
    print('Health check       : FAIL')
    print('Recovery           : keep', active, 'v'+current['version'])
    state_path.write_text(json.dumps(state, indent=2), encoding='utf-8')
    raise SystemExit(1)
print('Health check       : PASS')
state['active_slot']=inactive
state_path.write_text(json.dumps(state, indent=2), encoding='utf-8')
print('Activate           :', inactive)
print('Update             : SUCCESS')
