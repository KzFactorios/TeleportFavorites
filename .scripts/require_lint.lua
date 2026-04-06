#!/usr/bin/env lua
-- Lint for runtime requires and direct GUI API usage.
-- Usage: lua scripts/require_lint.lua [--fix] [path]

local root = arg[#arg]
local fix = false
for i, a in ipairs(arg) do if a == '--fix' then fix = true end end
if not root or root:match('%-%-') then root = '.' end

local function is_windows()
  return package.config:sub(1,1) == '\\'
end

local function list_files()
  local files = {}
  local cmd
  if is_windows() then
    cmd = string.format('cmd /C dir /B /S "%s\\*.lua"', root)
  else
    cmd = string.format('find "%s" -name "*.lua" -not -path "*/.git/*" -not -path "*/tests/*"', root)
  end
  local p = io.popen(cmd)
  if not p then return files end
  for line in p:lines() do
    local path = line:gsub('\\', '/')
    -- Skip .git, tests, and any lualib folders (external library code)
    if not path:match('/%.git/') and not path:match('/tests/') and not path:match('/lualib/') then table.insert(files, path) end
  end
  p:close()
  return files
end

local function check_file(path)
  local f = io.open(path, 'r')
  if not f then return nil end
  local i = 0
  local violations = {}
  for line in f:lines() do
    i = i + 1
    if line:match('^[ \t]+.*require%(') then table.insert(violations, {path=path, line=i, text=line, type='runtime-require'}) end
    if line:match('player%.gui%.screen%.add') then table.insert(violations, {path=path, line=i, text=line, type='direct-gui'}) end
  end
  f:close()
  return violations
end

local files = list_files()
local all_violations = {}
for _, f in ipairs(files) do
  local v = check_file(f)
  if v and #v > 0 then
    for _, w in ipairs(v) do table.insert(all_violations, w) end
  end
end

if #all_violations == 0 then
  os.exit(0)
end

if fix then
  -- run hoist fixer
  local ok = os.execute('lua "' .. '.scripts/hoist_requires.lua' .. '" "' .. root .. '"')
  if ok ~= 0 and ok ~= true then
    print('Hoist fixer failed; aborting.')
    os.exit(2)
  end
  -- re-run checks
  all_violations = {}
  files = list_files()
  for _, f in ipairs(files) do
    local v = check_file(f)
    if v and #v > 0 then
      for _, w in ipairs(v) do table.insert(all_violations, w) end
    end
  end
  if #all_violations == 0 then os.exit(0) end
end

print('Require lint found violations:')
for _, v in ipairs(all_violations) do
  print(string.format('%s:%d: [%s] %s', v.path, v.line, v.type, v.text))
end
os.exit(1)
