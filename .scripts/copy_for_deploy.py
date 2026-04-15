import os
import shutil

# 1. Setup and Environment
version = os.environ.get('INPUT_VERSION', '0.0.0')
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
DIST = os.path.join(ROOT, '.dist')
# The specific mod folder inside .dist
TARGET_DIR = os.path.join(DIST, f'TeleportFavorites_{version}')

# Configuration
EXCLUDE_DIRS = {'tests', 'script-output', '.cursor', '.dist', '.git', '.githooks', '.github', '.idea', '.project', '.scripts', '.vscode', 
    'graphics/.screenshots', 'graphics/.sprite_shop', 'graphics/.svgs'}
EXCLUDE_FILES = {
    '.busted', '.gitignore', '.luarc.json', '.test.*', 'coverage_summary.txt',
    'luacov.*', 'TeleportFavorites_workspace.code-workspace',
}

REQUIRED_ROOT_FILES = [
    'changelog.txt', 'constants.lua', 'control.lua', 'data.lua',
    'info.json', 'LICENSE', 'README.md', 'settings.lua', 'thumbnail.png',
]

# 2. Prepare Directories
if os.path.exists(DIST):
    shutil.rmtree(DIST)
os.makedirs(TARGET_DIR, exist_ok=True)

# 3. Generate release_notes.txt (Truncated version for GitHub)
changelog_path = os.path.join(ROOT, 'changelog.txt')
if os.path.exists(changelog_path):
    with open(changelog_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
        last_ten_lines = "".join(lines[-10:])

    with open(os.path.join(TARGET_DIR, 'release_notes.txt'), 'w', encoding='utf-8') as f:
        f.write("## Recent Changes\n")
        f.write(last_ten_lines)
        f.write("\n\n---\n*See the full changelog in the .zip file or on the Factorio Portal.*")

# 4. Copying Logic
def should_exclude(rel_path):
    parts = rel_path.split(os.sep)
    if any(part.startswith('.') and part != '.dist' for part in parts):
        return True
    if any(part in EXCLUDE_DIRS for part in parts):
        return True
    fname = parts[-1]
    if fname in EXCLUDE_FILES or fname.endswith(('_spec.lua', '_test.lua')):
        return True
    if fname.startswith('.') and fname != '.dist':
        return True
    return False

# Main copy loop
for dirpath, dirnames, filenames in os.walk(ROOT):
    rel_dir = os.path.relpath(dirpath, ROOT)
    
    if should_exclude(rel_dir):
        continue
        
    for fname in filenames:
        rel_file = os.path.join(rel_dir, fname)
        if should_exclude(rel_file):
            continue
            
        src = os.path.join(dirpath, fname)
        # Place all copied files into the target mod folder
        dst_dir = os.path.join(TARGET_DIR, rel_dir)
        os.makedirs(dst_dir, exist_ok=True)
        shutil.copy2(src, os.path.join(dst_dir, fname))

# 5. Thumbnail Fallback logic
thumbnail_dst = os.path.join(TARGET_DIR, 'thumbnail.png')
if not os.path.exists(thumbnail_dst):
    logo_144 = os.path.join(ROOT, 'graphics', 'logo_144.png')
    if os.path.exists(logo_144):
        shutil.copy2(logo_144, thumbnail_dst)
    else:
        print('WARNING: thumbnail.png not found and no fallback graphics/logo_144.png available.')

# 6. Cleanup empty files
def remove_empty_files(path):
    for dirpath, _, filenames in os.walk(path):
        for fname in filenames:
            fpath = os.path.join(dirpath, fname)
            if os.path.exists(fpath) and os.path.getsize(fpath) == 0:
                os.remove(fpath)

remove_empty_files(DIST)

print(f'Production files successfully staged to {TARGET_DIR}')