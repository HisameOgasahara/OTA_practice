"""Validate signed manifest bytes, payload integrity and version policy."""
import hashlib
import subprocess
import tempfile
from pathlib import Path


class Rejected(Exception):
    pass


def verify_signature(manifest_bytes, signature, public_key, timeout):
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        manifest = root / 'manifest.json'
        sig = root / 'signature.sig'
        manifest.write_bytes(manifest_bytes)
        sig.write_bytes(signature)
        result = subprocess.run(
            ['openssl', 'dgst', '-sha256', '-verify', str(public_key),
             '-signature', str(sig), str(manifest)],
            capture_output=True, timeout=timeout)
    if result.returncode:
        raise Rejected('SIGNATURE_REJECT')
    print('Signature: PASS')


def verify_payload(manifest, payload):
    if hashlib.sha256(payload).hexdigest() != manifest['sha256'].lower():
        raise Rejected('HASH_REJECT')
    print('SHA-256: PASS')


def verify_version(manifest, current):
    def parse(value):
        parts = value.split('.')
        if not parts or any(not part.isascii() or not part.isdigit() for part in parts):
            raise ValueError('Invalid version')
        return tuple(map(int, parts))
    if parse(manifest['version']) <= parse(current['version']):
        raise Rejected('VERSION_REJECT')
    print('Version: PASS')
