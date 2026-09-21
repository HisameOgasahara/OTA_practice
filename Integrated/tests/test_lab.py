"""Exercise the real PowerShell repository/server and Python vehicle over loopback."""
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import unittest
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]


class IntegratedLabTest(unittest.TestCase):
    def test_full_run_and_failure_detection(self):
        self.assertIsNotNone(shutil.which('openssl'), 'Put OpenSSL on PATH')
        with tempfile.TemporaryDirectory() as temporary:
            work = Path(temporary)
            run = work / 'server'
            run.mkdir()
            vehicle = work / 'remote'
            shutil.copytree(ROOT / 'vehicle', vehicle / 'vehicle')
            shutil.copytree(ROOT / 'scenarios', vehicle / 'scenarios')
            with socket.socket() as probe:
                probe.bind(('127.0.0.1', 0))
                port = probe.getsockname()[1]
            settings = dict(pc_ip='127.0.0.1', ip='127.0.0.1', port=port,
                            http_timeout_seconds=2, remote_command_timeout_seconds=10,
                            pc_server_ip='127.0.0.1')
            (run / 'server.json').write_text(json.dumps(settings), encoding='utf-8')
            (vehicle / 'server_config.json').write_text(json.dumps(settings), encoding='utf-8')
            shell = Path(os.environ['SystemRoot']) / 'System32/WindowsPowerShell/v1.0/powershell.exe'
            environment = dict(os.environ)
            environment['PSModulePath'] = str(shell.parent / 'Modules')
            with (work / 'server-output.txt').open('w', encoding='utf-8') as log:
                process = subprocess.Popen([str(shell), '-NoProfile', '-ExecutionPolicy', 'Bypass',
                    '-File', str(ROOT / 'server/Start-Server.ps1'), '-RunDir', str(run),
                    '-OwnerPid', str(os.getpid())], stdout=log, stderr=log, env=environment)
                def wait(name):
                    deadline = time.monotonic() + 15
                    while not (run / name).exists():
                        self.assertFalse((run / 'server-error').exists(),
                                         (run / 'server-error').read_text(encoding='utf-8') if (run / 'server-error').exists() else '')
                        self.assertIsNone(process.poll(), 'Server exited early')
                        self.assertLess(time.monotonic(), deadline, f'Timeout: {name}')
                        time.sleep(.05)
                def execute(case):
                    return subprocess.run([sys.executable, str(vehicle / 'scenarios/verify_scenario.py'),
                        case['id']], capture_output=True, text=True, timeout=20)
                try:
                    wait('ready')
                    cases = json.loads((ROOT / 'scenarios/scenarios.json').read_text(encoding='utf-8'))
                    for case in cases:
                        (run / 'request.tmp').write_text(json.dumps({'id': case['id']}), encoding='utf-8')
                        (run / 'request.tmp').replace(run / 'request.json')
                        wait(case['id'] + '.ready')
                        result = execute(case)
                        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                        record = json.loads((vehicle / (case['id'] + '.result.json')).read_text())
                        self.assertEqual(record['decision'], case['expected']['decision'])
                        print(case['id'], record['decision'], record['headlamp'])
                    for invalid in ('/../server.json', '/password.tmp', '/%2e%2e/config.json'):
                        with self.assertRaises(urllib.error.HTTPError) as error:
                            urllib.request.urlopen(f'http://127.0.0.1:{port}{invalid}', timeout=3)
                        self.assertEqual(error.exception.code, 404)
                    # A client returning 1 is insufficient: the expected reason must match.
                    cases[-1]['expected']['decision'] = 'HASH_REJECT'
                    (vehicle / 'scenarios/scenarios.json').write_text(json.dumps(cases), encoding='utf-8')
                    result = execute(cases[-1])
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn('Unexpected OTA decision', result.stderr)
                    (run / 'stop').write_text('stop')
                    process.wait(timeout=10)
                    self.assertEqual(process.returncode, 0)
                    # A transport failure must not pass as an anticipated security rejection.
                    result = execute(cases[-1])
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn('Client failed without an OTA decision', result.stderr)
                finally:
                    (run / 'stop').write_text('stop')
                    if process.poll() is None:
                        process.terminate()
                        process.wait(timeout=10)


if __name__ == '__main__':
    unittest.main()
