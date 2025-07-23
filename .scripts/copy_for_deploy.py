import os
import shutil

# Configuration
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
DIST = os.path.join(ROOT, '.dist')
EXCLUDE_DIRS = {'tests', '.git', '.github', '.vscode', '.project', '.scripts', '.dist'}
EXCLUDE_FILES = {
    'TeleportFavorites_workspace.code-workspace',
}

REQUIRED_ROOT_FILES = [
    'changelog.txt',
    'constants.lua',
    'control.lua',
    'data.lua',
    'info.json',
    'LICENSE',
    'README.md',
    'settings.lua',
]

# Utility: Remove empty files
def remove_empty_files(path):
    for dirpath, _, filenames in os.walk(path):
        for fname in filenames:
            fpath = os.path.join(dirpath, fname)
            try:
                if os.path.getsize(fpath) == 0:
                    os.remove(fpath)
            except Exception:
                pass

# Utility: Should file/dir be excluded?
def should_exclude(rel_path):
    parts = rel_path.split(os.sep)
    if any(part.startswith('.') and part != '.dist' for part in parts):
        return True
    if any(part in EXCLUDE_DIRS for part in parts):
        return True
    fname = parts[-1]
    if fname in EXCLUDE_FILES:
        return True
    if fname.endswith('_spec.lua') or fname.endswith('_test.lua'):
        return True
    if fname.startswith('.') and fname != '.dist':
        return True
    return False

# Copy files
if os.path.exists(DIST):
    shutil.rmtree(DIST)
os.makedirs(DIST, exist_ok=True)



# Always copy required root files to .dist
for fname in REQUIRED_ROOT_FILES:
    src = os.path.join(ROOT, fname)
    dst = os.path.join(DIST, fname)
    if os.path.exists(src):
        shutil.copy2(src, dst)

for dirpath, dirnames, filenames in os.walk(ROOT):
    rel_dir = os.path.relpath(dirpath, ROOT)
    # Skip excluded dirs
    if should_exclude(rel_dir):
        continue
    # Copy files
    for fname in filenames:
        rel_file = os.path.join(rel_dir, fname)
        if should_exclude(rel_file):
            continue
        # Skip root files already copied
        if rel_dir == '.' and fname in REQUIRED_ROOT_FILES:
            continue
        src = os.path.join(dirpath, fname)
        dst_dir = os.path.join(DIST, rel_dir)
        os.makedirs(dst_dir, exist_ok=True)
        dst = os.path.join(dst_dir, fname)
        shutil.copy2(src, dst)

# Remove empty files from .dist
remove_empty_files(DIST)

print('Production files copied to .dist.')
