import os
import re

DIST = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '.dist'))
# Common dev flags/settings to check for
DEV_FLAG_PATTERNS = [
    r'DEV_MODE',
    r'DEBUG',
    r'ENABLE_TEST_FEATURES',
    r'TEST_',
    r'EXPERIMENTAL',
    r'LOG_LEVEL',
    r'print\(',
    r'warn_log',
    r'debug_log',
]

found = []
for dirpath, _, filenames in os.walk(DIST):
    for fname in filenames:
        if fname.endswith('.lua') or fname.endswith('.json'):
            fpath = os.path.join(dirpath, fname)
            with open(fpath, 'r', encoding='utf-8') as f:
                content = f.read()
                for pattern in DEV_FLAG_PATTERNS:
                    for match in re.finditer(pattern, content):
                        found.append((fpath, match.group(), match.start()))

if found:
    print('Forbidden dev flags/settings found:')
    for fpath, flag, pos in found:
        print(f'  {fpath}: {flag} (pos {pos})')
    exit(1)
else:
    print('No forbidden dev flags/settings found in .dist.')
