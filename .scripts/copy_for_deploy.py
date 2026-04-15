import os
import shutil
import sys

# 1. Environment Setup (RELEASE_VERSION in CI; INPUT_VERSION legacy local)
version = os.environ.get('RELEASE_VERSION') or os.environ.get('INPUT_VERSION')
if os.environ.get('GITHUB_ACTIONS') == 'true' and not version:
    print('Error: RELEASE_VERSION must be set in GitHub Actions', file=sys.stderr)
    sys.exit(1)
version = version or '0.0.0'
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
DIST = os.path.join(ROOT, '.dist')
# Staging folder: .dist/TeleportFavorites_<version>/
TARGET_DIR = os.path.join(DIST, f'TeleportFavorites_{version}')

# Configuration
EXCLUDE_DIRS = {
    'tests', 'script-output', '.cursor', '.dist', '.git', '.githooks', 
    '.github', '.idea', '.project', '.scripts', '.vscode', 
    'graphics/.screenshots', 'graphics/.sprite_shop', 'graphics/.svgs'
}
EXCLUDE_FILES = {
    '.busted', '.gitignore', '.luarc.json', '.test.*', 'coverage_summary.txt',
    'luacov.*', 'TeleportFavorites_workspace.code-workspace',
}

# 2. Prepare Directories
if os.path.exists(DIST):
    shutil.rmtree(DIST)
os.makedirs(TARGET_DIR, exist_ok=True)

# 3. Generate release_notes.txt (Truncated)
changelog_path = os.path.join(ROOT, 'changelog.txt')
if os.path.exists(changelog_path):
    with open(changelog_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
        last_ten_lines = "".join(lines[-10:])
    
    with open(os.path.join(TARGET_DIR, 'release_notes.txt'), 'w', encoding='utf-8') as f:
        f.write("## Recent Changes\n")
        f.write(last_ten_lines)
        f.write("\n\n---\n*See the full changelog in the .zip file or on the Factorio Portal.*")

# 4. Copying Logic (Recursive)
def should_exclude(rel_path):
    # Ignore the .dist directory itself during the walk
    if rel_path.startswith('.dist'): return True
    # Basic filter
    parts = rel_path.split(os.sep)
    if any(p.startswith('.') and p != '.' for p in parts): return True
    if any(p in EXCLUDE_DIRS for p in parts): return True
    fname = parts[-1]
    if fname in EXCLUDE_FILES or fname.endswith(('_spec.lua', '_test.lua')): return True
    return False

for dirpath, dirnames, filenames in os.walk(ROOT):
    rel_dir = os.path.relpath(dirpath, ROOT)
    
    if should_exclude(rel_dir):
        continue
        
    for fname in filenames:
        rel_file = os.path.join(rel_dir, fname)
        if should_exclude(rel_file):
            continue
            
        src = os.path.join(dirpath, fname)
        # Flatten structure: Put root files at the root of TARGET_DIR
        # Put nested files in corresponding sub-folders in TARGET_DIR
        dst_path = os.path.join(TARGET_DIR, rel_dir if rel_dir != '.' else '', fname)
        os.makedirs(os.path.dirname(dst_path), exist_ok=True)
        shutil.copy2(src, dst_path)

# 5. Thumbnail Fallback
thumbnail_dst = os.path.join(TARGET_DIR, 'thumbnail.png')
if not os.path.exists(thumbnail_dst):
    logo_144 = os.path.join(ROOT, 'graphics', 'logo_144.png')
    if os.path.exists(logo_144):
        shutil.copy2(logo_144, thumbnail_dst)

# 6. Cleanup empty files
for dirpath, _, filenames in os.walk(TARGET_DIR):
    for fname in filenames:
        fpath = os.path.join(dirpath, fname)
        if os.path.exists(fpath) and os.path.getsize(fpath) == 0:
            os.remove(fpath)

print(f'Production files successfully staged to {TARGET_DIR}')