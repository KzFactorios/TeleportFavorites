import os
import re

DIST = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '.dist'))
CHANGELOG = os.path.join(DIST, 'changelog.txt')

HEADER_PATTERN = re.compile(r'^-{99}$')
VERSION_PATTERN = re.compile(r'^Version: \d+\.\d+\.\w+$')
DATE_PATTERN = re.compile(r'^Date: \d{4}-\d{2}-\d{2}$')
CATEGORY_PATTERN = re.compile(r'^  [^:]+:$')
ENTRY_PATTERN = re.compile(r'^    - .+')
CONTINUATION_PATTERN = re.compile(r'^      .+')

errors = []
if not os.path.exists(CHANGELOG):
    errors.append('changelog.txt not found in .dist')
else:
    with open(CHANGELOG, 'r', encoding='utf-8') as f:
        lines = [line.rstrip('\n') for line in f]
    i = 0
    while i < len(lines):
        # Header line
        if not HEADER_PATTERN.match(lines[i]):
            errors.append(f'Line {i+1}: Expected 99-dash header')
        i += 1
        # Version line
        if i >= len(lines) or not VERSION_PATTERN.match(lines[i]):
            errors.append(f'Line {i+1}: Expected Version: X.Y.Z')
        i += 1
        # Optional date line
        if i < len(lines) and DATE_PATTERN.match(lines[i]):
            i += 1
        # Categories and entries
        while i < len(lines) and lines[i] != '' and not HEADER_PATTERN.match(lines[i]):
            if CATEGORY_PATTERN.match(lines[i]):
                i += 1
                while i < len(lines) and (ENTRY_PATTERN.match(lines[i]) or CONTINUATION_PATTERN.match(lines[i])):
                    i += 1
            elif lines[i] == '':
                i += 1
            else:
                errors.append(f'Line {i+1}: Unexpected line format: {lines[i]}')
                i += 1
        # Skip empty lines before next header
        while i < len(lines) and lines[i] == '':
            i += 1

    # Check for tabs and trailing whitespace
    for idx, line in enumerate(lines):
        if '\t' in line:
            errors.append(f'Line {idx+1}: Tab character found')
        if line != line.rstrip():
            errors.append(f'Line {idx+1}: Trailing whitespace found')

if errors:
    print('changelog.txt validation failed:')
    for err in errors:
        print('  ' + err)
    exit(1)
else:
    print('changelog.txt format is valid.')
