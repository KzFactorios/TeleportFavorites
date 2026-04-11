

import os
import re
import sys

# Ensure stdout uses UTF-8 encoding for all output (Python 3.7+)
try:
    sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    try:
        import codecs
        sys.stdout = codecs.getwriter('utf-8')(sys.stdout.detach())
    except Exception:
        pass

def safe_print(msg):
    try:
        print(msg)
    except UnicodeEncodeError:
        try:
            print(msg.encode('utf-8', errors='replace').decode('utf-8', errors='replace'))
        except Exception:
            try:
                print(msg.encode('ascii', errors='replace').decode('ascii'))
            except Exception:
                with open('strip_comments_debug.log', 'a', encoding='utf-8') as logf:
                    logf.write(str(msg) + '\n')

DIST = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '.dist'))
LICENSE_HEADER_PATTERN = re.compile(r'^(--.*copyright|--.*license)', re.IGNORECASE)

# Remove comments from Lua files, including EmmyLua (---@...) annotations, except license headers
def strip_comments_from_file(filepath):
    safe_print(f"Processing file: {filepath}")
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
    for idx, line in enumerate(lines):
        stripped = line.lstrip()
        if not in_block_comment and '--[[' in line:
            safe_print(f"[{idx}] Block comment start detected: {line.strip()}")
            start = line.find('--[[')
            if ']]' in line:
                end = line.find(']]', start)
                safe_print(f"[{idx}] Block comment end detected on same line: {line.strip()}")
                line = line[:start] + line[end+2:]
                if line.strip() == '':
                    safe_print(f"[{idx}] Line empty after block comment removal, skipping.")
                    continue
                stripped = line.lstrip()
            else:
                in_block_comment = True
                safe_print(f"[{idx}] Entering block comment mode.")
                line = line[:start]
                if line.strip() == '':
                    safe_print(f"[{idx}] Line empty before block comment, skipping.")
                    continue
                stripped = line.lstrip()
        if in_block_comment:
            if ']]' in line:
                end = line.find(']]')
                safe_print(f"[{idx}] Block comment end detected: {line.strip()}")
                line = line[end+2:]
                in_block_comment = False
                if line.strip() == '':
                    safe_print(f"[{idx}] Line empty after block comment end, skipping.")
                    continue
                stripped = line.lstrip()
            else:
                safe_print(f"[{idx}] Inside block comment, skipping line: {line.strip()}")
                continue
        if stripped.startswith('--'):
            if LICENSE_HEADER_PATTERN.match(stripped):
                safe_print(f"[{idx}] License header preserved: {line.strip()}")
                new_lines.append(line.rstrip() + '\n')
            else:
                kind = "EmmyLua annotation" if stripped.startswith('---@') else "comment"
                safe_print(f"[{idx}] Standalone {kind} removed: {line.strip()}")
            continue
        if forbidden_re.match(line):
            safe_print(f"[{idx}] Forbidden dev flag/setting removed: {line.strip()}")
            continue
        if '--' in line and not 'http' in line:
            comment_pos = line.find('--')
            code_before = line[:comment_pos].rstrip()
            comment = line[comment_pos:]
            if comment.lstrip().startswith('---@'):
                safe_print(f"[{idx}] Inline EmmyLua annotation removed: {line.strip()}")
                line = code_before + '\n'
            else:
                safe_print(f"[{idx}] Inline comment removed: {line.strip()}")
                line = code_before + '\n'
            new_lines.append(line)
            continue
        new_lines.append(line.rstrip() + '\n')
    while new_lines and new_lines[0].strip() == '':
        new_lines.pop(0)
    while new_lines and new_lines[-1].strip() == '':
        new_lines.pop()
    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)

for dirpath, _, filenames in os.walk(DIST):
    for fname in filenames:
        if fname.endswith('.lua'):
            strip_comments_from_file(os.path.join(dirpath, fname))

safe_print('Comments and EmmyLua annotations stripped from Lua files in .dist.')
