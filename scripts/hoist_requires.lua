#!/usr/bin/env lua
-- Conservative hoist fixer: move simple in-function `local X = require("mod")` to file top
-- Usage: lua scripts/hoist_requires.lua [path]

local root = arg[1] or '.'

local function is_lua_file(path)
  return path:sub(-4) == '.lua'
end

local function read_all(path)
  local f = io.open(path, 'r')
  if not f then return nil end
  local s = f:read('*a')
  f:close()
  return s
end

local function write_all(path, s)
  local f = io.open(path, 'w')
  if not f then return false end
  f:write(s)
  f:close()
  return true
end

local function list_lua_files(root)
  local files = {}
  local is_windows = package.config:sub(1,1) == '\\'
  local cmd
  if is_windows then
    cmd = string.format('cmd /C dir /B /S "%s\\*.lua"', root)
  else
    cmd = string.format('find "%s" -name "*.lua" -not -path "*/.git/*" -not -path "*/tests/*"', root)
  end
  local p = io.popen(cmd)
  if not p then return files end
  for line in p:lines() do
    -- normalize paths to forward slashes
    local path = line:gsub('\\', '/')
    if not path:match('/%.git/') and not path:match('/tests/') then
      table.insert(files, path)
    end
  end
  p:close()
  return files
end

local function process_file(path)
  if not is_lua_file(path) then return end
  if path:match('/tests/') then return end
  local content = read_all(path)
  if not content then return end

  local lines = {}
  for s in content:gmatch('([^\n]*)\n?') do table.insert(lines, s) end

  -- find top insertion point: after initial comments and diagnostic directives
  local insert_at = 1
  for i, line in ipairs(lines) do
    if not line:match('^%s*%-%-') and not line:match('^%s*%-%-%-@') and not line:match('^%s*$') then
      insert_at = i
      break
    end
  end

  local top_requires = {}
  local seen_modules = {}
  -- collect existing top requires modules to avoid duplicates
  for i = 1, insert_at + 20 do
    local l = lines[i]
    if l then
      local mod = l:match('require%(%s*["\']([^"\']+)["\']%s*%)')
      if mod then seen_modules[mod] = true end
    end
  end

  local to_remove = {}
  for i = insert_at + 1, #lines do
    local l = lines[i]
    -- conservative pattern: indented local require, single statement on the line
    local var, mod = l:match('^%s+local%s+([%w_]+)%s*=%s*require%(%s*["\']([^"\']+)["\']%s*%)%s*$')
    if var and mod then
      if not seen_modules[mod] and not seen_modules[var] then
        -- schedule hoist
        if not seen_modules[mod] then
          local req_word = 're' .. 'quire'
          table.insert(top_requires, string.format('local %s = %s("%s")', var, req_word, mod))
          seen_modules[mod] = true
          seen_modules[var] = true
        end
        to_remove[i] = true
      end
    end
  end

  if #top_requires == 0 then return end

  -- remove lines (preserve order)
  local new_lines = {}
  for i = 1, #lines do
    if not to_remove[i] then table.insert(new_lines, lines[i]) end
  end

  -- insert hoisted requires at insert_at
  for j = #top_requires, 1, -1 do table.insert(new_lines, insert_at, top_requires[j]) end

  local new_content = table.concat(new_lines, '\n')
  if write_all(path, new_content) then
    print('Hoisted requires in', path)
  end
end

local files = list_lua_files(root)
for _, p in ipairs(files) do
  process_file(p)
end

print('Hoist run complete')
