#!/usr/bin/env python3
import json, sys
from pathlib import Path
if len(sys.argv) != 2:
    print("Usage: python3 common/set_server_ip.py <Windows-PC-IPv4>")
    raise SystemExit(2)
ip=sys.argv[1].strip()
parts=ip.split('.')
if len(parts)!=4 or any(not p.isdigit() or not (0<=int(p)<=255) for p in parts):
    print("Invalid IPv4 address:", ip); raise SystemExit(2)
p=Path(__file__).with_name('server_config.json')
p.write_text(json.dumps({'pc_server_ip':ip}, indent=2), encoding='utf-8')
print(f"[OK] Windows OTA Server IP = {ip}")
print(f"Day 2 URL: http://{ip}:8000")
print(f"Day 3 URL: http://{ip}:8001")
