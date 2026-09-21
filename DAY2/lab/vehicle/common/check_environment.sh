#!/bin/bash
set -u
check(){ if command -v "$1" >/dev/null 2>&1; then echo "[OK] $1: $($1 --version 2>&1 | head -1)"; else echo "[FAIL] $1 not found"; fi; }
check python3
check openssl
python3 - <<'PY2'
import json
from pathlib import Path
p=Path('common/server_config.json')
if p.exists():
    print('[OK] server_config.json:', json.loads(p.read_text()).get('pc_server_ip'))
else:
    print('[FAIL] server_config.json not found')
PY2
