import os
import re

DIST = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '.dist'))
LICENSE_HEADER_PATTERN = re.compile(r'^(--.*copyright|--.*license)', re.IGNORECASE)

# Remove comments from Lua files, except license headers at the top and EmmyLua annotations
def strip_comments_from_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    new_lines = []
    forbidden_patterns = [
        r'^\s*debug_log\b',
        r'^\s*warn_log\b',
        r'^\s*print\s*\(',
        r'^\s*DEBUG\b'
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
        # Preserve EmmyLua annotation comments
        if stripped.startswith('---@'):
            new_lines.append(line.rstrip() + '\n')
            continue
        # Remove all standalone comment lines (except license headers)
        if stripped.startswith('--'):
            if LICENSE_HEADER_PATTERN.match(stripped):
                new_lines.append(line.rstrip() + '\n')
            continue
        # Remove lines with forbidden dev flags/settings (only if line starts with them)
        if forbidden_re.match(line):
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

print('Comments stripped from Lua files in .dist, EmmyLua annotations preserved.')
