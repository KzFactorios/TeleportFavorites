

import os
import re
import sys

# Ensure stdout uses UTF-8 encoding for all output (Python 3.7+)
try:
    sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    # For older Python versions or if reconfigure fails, replace stdout with UTF-8 writer
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
                # Final fallback: write to a log file
                with open('strip_comments_debug.log', 'a', encoding='utf-8') as logf:
                    logf.write(str(msg) + '\n')

def safe_print(msg):
    try:
        print(msg)
    except UnicodeEncodeError:
        print(msg.encode('utf-8', errors='replace').decode('utf-8', errors='replace'))

DIST = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '.dist'))
LICENSE_HEADER_PATTERN = re.compile(r'^(--.*copyright|--.*license)', re.IGNORECASE)

# Remove comments from Lua files, except license headers at the top and EmmyLua annotations
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
        # Block comment start (inline or multiline)
        if not in_block_comment and '--[[' in line:
            safe_print(f"[{idx}] Block comment start detected: {line.strip()}")
            start = line.find('--[[')
            # If block comment starts and ends on the same line
            if ']]' in line:
                end = line.find(']]', start)
                safe_print(f"[{idx}] Block comment end detected on same line: {line.strip()}")
                # Remove the block comment, preserve code before and after
                line = line[:start] + line[end+2:]
                if line.strip() == '':
                    safe_print(f"[{idx}] Line empty after block comment removal, skipping.")
                    continue
                stripped = line.lstrip()
            else:
                # Block comment starts here, may span multiple lines
                in_block_comment = True
                safe_print(f"[{idx}] Entering block comment mode.")
                # Preserve code before block comment
                line = line[:start]
                if line.strip() == '':
                    safe_print(f"[{idx}] Line empty before block comment, skipping.")
                    continue
                stripped = line.lstrip()
        # Block comment end (multiline)
        if in_block_comment:
            if ']]' in line:
                end = line.find(']]')
                safe_print(f"[{idx}] Block comment end detected: {line.strip()}")
                # Preserve code after block comment ends
                line = line[end+2:]
                in_block_comment = False
                if line.strip() == '':
                    safe_print(f"[{idx}] Line empty after block comment end, skipping.")
                    continue
                stripped = line.lstrip()
            else:
                safe_print(f"[{idx}] Inside block comment, skipping line: {line.strip()}")
                continue
        # Preserve EmmyLua annotation comments (including ---@diagnostic)
        if stripped.startswith('---@'):
            safe_print(f"[{idx}] EmmyLua annotation preserved: {line.strip()}")
            new_lines.append(line.rstrip() + '\n')
            continue
        # Remove all standalone comment lines (except license headers)
        if stripped.startswith('--'):
            if LICENSE_HEADER_PATTERN.match(stripped):
                safe_print(f"[{idx}] License header preserved: {line.strip()}")
                new_lines.append(line.rstrip() + '\n')
            else:
                safe_print(f"[{idx}] Standalone comment removed: {line.strip()}")
            continue
        # Remove lines with forbidden dev flags/settings (only if line starts with them)
        if forbidden_re.match(line):
            safe_print(f"[{idx}] Forbidden dev flag/setting removed: {line.strip()}")
            continue
        # Remove inline comments (but not URLs), preserve code before '--'
        if '--' in line and not 'http' in line:
            comment_pos = line.find('--')
            code_before = line[:comment_pos].rstrip()
            comment = line[comment_pos:]
            # If annotation, preserve everything after '--'
            if comment.lstrip().startswith('---@'):
                safe_print(f"[{idx}] Inline EmmyLua annotation preserved: {line.strip()}")
                # Preserve code before '--', annotation, and any code after annotation
                line = code_before + ' ' + comment.rstrip() + '\n'
            else:
                safe_print(f"[{idx}] Inline comment removed: {line.strip()}")
                # Only preserve code before '--'
                line = code_before + '\n'
            new_lines.append(line)
            continue
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

safe_print('Comments stripped from Lua files in .dist, EmmyLua annotations preserved.')
