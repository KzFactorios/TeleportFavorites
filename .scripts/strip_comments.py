import os
import re
import sys

# RELEASE_VERSION in CI; INPUT_VERSION legacy local
version = os.environ.get('RELEASE_VERSION') or os.environ.get('INPUT_VERSION')
if os.environ.get('GITHUB_ACTIONS') == 'true' and not version:
    print('Error: RELEASE_VERSION must be set in GitHub Actions', file=sys.stderr)
    sys.exit(1)
version = version or '0.0.0'
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
DIST = os.path.join(ROOT, '.dist', f'TeleportFavorites_{version}')

# License header check
LICENSE_HEADER_PATTERN = re.compile(r'^\s*(--.*copyright|--.*license)', re.IGNORECASE)

# Lua long comments: --[=*[ ... ]=*]  (same number of = on open/close)
LONG_COMMENT_PATTERN = re.compile(r'--\[(=*)\[(.*?)\]\1\]', re.DOTALL)


def strip_long_comments(content: str) -> str:
    """Remove --[[ ... ]] / --[=[ ... ]=] blocks (balanced bracket form)."""
    return LONG_COMMENT_PATTERN.sub('', content)


def strip_lua_comments(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    content = strip_long_comments(content)
    lines = content.splitlines()
    new_lines = []

    forbidden_re = re.compile(r'^\s*(debug_log|warn_log|print|DEBUG)\b', re.IGNORECASE)

    for line in lines:
        # Keep license headers
        if LICENSE_HEADER_PATTERN.match(line):
            new_lines.append(line)
            continue

        # Check for forbidden dev flags
        if forbidden_re.match(line):
            continue

        stripped = line.lstrip()

        # Full-line LuaDoc / EmmyLua (---@ ...): drop entire line. Must run before
        # inline -- removal — re.sub(r'--(?!-@)…') on '---@foo' can match the 2nd
        # '--' and leave a stray '-' (invalid Lua).
        if stripped.startswith('---'):
            continue

        # Remove inline / rest-of-line comments (-- …)
        line = re.sub(r'--(?!-@).*$', '', line)

        if line.strip() == '':
            continue

        new_lines.append(line.rstrip())

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write('\n'.join(new_lines) + '\n')


for dirpath, _, filenames in os.walk(DIST):
    for fname in filenames:
        if fname.endswith('.lua'):
            strip_lua_comments(os.path.join(dirpath, fname))

print(f"Comments stripped from Lua files in {DIST}")
