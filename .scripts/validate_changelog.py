import os
import re
import sys

# Get version from environment
version = os.environ.get('INPUT_VERSION', '0.0.0')
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
TARGET_DIR = os.path.join(ROOT, '.dist', f'TeleportFavorites_{version}')
CHANGELOG = os.path.join(TARGET_DIR, 'changelog.txt')

HEADER_PATTERN = re.compile(r'^-{99}$')
VERSION_PATTERN = re.compile(r'^Version: \d+\.\d+\.\d+$') # Changed \w to \d for Z
DATE_PATTERN = re.compile(r'^Date: \d{4}-\d{2}-\d{2}$')
CATEGORY_PATTERN = re.compile(r'^  [^:]+:$')
ENTRY_PATTERN = re.compile(r'^    - .+')
CONTINUATION_PATTERN = re.compile(r'^      .+')

errors = []

if not os.path.exists(CHANGELOG):
    print(f"Error: changelog.txt not found at {CHANGELOG}")
    sys.exit(1)

with open(CHANGELOG, 'r', encoding='utf-8') as f:
    lines = [line.rstrip() for line in f]

# 1. Structural Validation (Declarative)
# Check for tabs or trailing spaces first
for idx, line in enumerate(lines):
    if '\t' in line:
        errors.append(f'Line {idx+1}: Tab character found')
    if line != line.rstrip():
        errors.append(f'Line {idx+1}: Trailing whitespace found')

# 2. Pattern Matching
# Note: Factorio changelogs often have empty lines between blocks; 
# your script should be tolerant of them.
for idx, line in enumerate(lines):
    if not line: continue  # Skip empty lines
    
    # Check if this line matches any known good format
    is_valid = (
        HEADER_PATTERN.match(line) or
        VERSION_PATTERN.match(line) or
        DATE_PATTERN.match(line) or
        CATEGORY_PATTERN.match(line) or
        ENTRY_PATTERN.match(line) or
        CONTINUATION_PATTERN.match(line)
    )
    
    if not is_valid:
        errors.append(f'Line {idx+1}: Unexpected format: "{line.strip()}"')

if errors:
    print('changelog.txt validation failed:')
    for err in errors:
        print(f'  {err}')
    sys.exit(1)
else:
    print('changelog.txt format is valid.')