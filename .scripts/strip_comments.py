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
    forbidden_patterns = [
        r'debug_log',
        r'warn_log',
        r'print\s*\(',
        r'DEBUG'
    ]
    forbidden_re = re.compile('|'.join(forbidden_patterns), re.IGNORECASE)
    in_block_comment = False
    for line in lines:
        stripped = line.lstrip()
        # Block comment start
        if not in_block_comment and stripped.startswith('--[['):
            in_block_comment = True
            continue
        # Block comment end
        if in_block_comment:
            if ']]' in line:
                in_block_comment = False
            continue
        # Remove all standalone comment lines
        if stripped.startswith('--'):
            continue
        # Remove lines with forbidden dev flags/settings
        if forbidden_re.search(line):
            continue
        # Remove inline comments (but not URLs), preserve code before '--'
        if '--' in line and not 'http' in line:
            comment_pos = line.find('--')
            code_before = line[:comment_pos].rstrip()
            line = code_before + '\n'
        # Remove trailing whitespace
        new_lines.append(line.rstrip() + '\n')
    # Remove leading blank lines
    while new_lines and new_lines[0].strip() == '':
        new_lines.pop(0)
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
