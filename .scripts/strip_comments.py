import os
import re

DIST = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '.dist'))
LICENSE_HEADER_PATTERN = re.compile(r'^(--.*copyright|--.*license)', re.IGNORECASE)

# Remove comments from Lua files, except license headers at the top
def strip_comments_from_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    new_lines = []
    license_header = True
    for line in lines:
        stripped = line.lstrip()
        # Preserve license header at the top
        if license_header and LICENSE_HEADER_PATTERN.match(stripped):
            new_lines.append(line)
            continue
        license_header = False if not stripped.startswith('--') else license_header
        # Remove full-line comments
        if stripped.startswith('--') and not license_header:
            continue
        # Remove inline comments (but not URLs)
        if '--' in line and not 'http' in line:
            line = re.sub(r'--.*', '', line)
        # Remove trailing whitespace
        new_lines.append(line.rstrip() + '\n')
    # Remove trailing blank lines
    while new_lines and new_lines[-1].strip() == '':
        new_lines.pop()
    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)

for dirpath, _, filenames in os.walk(DIST):
    for fname in filenames:
        if fname.endswith('.lua'):
            strip_comments_from_file(os.path.join(dirpath, fname))

print('Comments stripped from Lua files in .dist.')
