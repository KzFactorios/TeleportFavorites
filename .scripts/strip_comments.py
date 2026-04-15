import os
import re
import sys

# Get version from env, same as your deployment script
version = os.environ.get('INPUT_VERSION', '0.0.0')
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
DIST = os.path.join(ROOT, '.dist', f'TeleportFavorites_{version}')

# License header check
LICENSE_HEADER_PATTERN = re.compile(r'^\s*(--.*copyright|--.*license)', re.IGNORECASE)

def strip_lua_comments(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Regex to match Block Comments (--[[ ... ]]) - multiline supported
    # 2. Regex to match standard comments (-- ... ) 
    #    (Excluding EmmyLua ---@ and keeping License headers)
    
    # We process line-by-line for forbidden patterns, but use regex for global comment removal
    lines = content.splitlines()
    new_lines = []
    
    forbidden_re = re.compile(r'^\s*(debug_log|warn_log|print|DEBUG)\b', re.IGNORECASE)

    for line in lines:
        stripped = line.lstrip()
        
        # Keep license headers
        if LICENSE_HEADER_PATTERN.match(line):
            new_lines.append(line)
            continue
            
        # Check for forbidden dev flags
        if forbidden_re.match(line):
            continue

        # Remove -- inline comments (but not if it's EmmyLua ---@ if you want to keep them, 
        # or remove if you want them gone)
        # This regex removes -- followed by anything, unless it's a specific pattern
        line = re.sub(r'--(?!-@).*$', '', line)
        
        # Remove empty lines resulting from comment stripping
        if line.strip() == '':
            continue
            
        new_lines.append(line.rstrip())

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write('\n'.join(new_lines) + '\n')

# Walk the specific target directory
for dirpath, _, filenames in os.walk(DIST):
    for fname in filenames:
        if fname.endswith('.lua'):
            strip_lua_comments(os.path.join(dirpath, fname))

print(f"Comments stripped from Lua files in {DIST}")