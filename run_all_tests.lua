-- Run all tests and generate coverage report
package.path = "./?.lua;" .. package.path

-- Add luacov paths to package.path (if available)
local lua_version = _VERSION:match("Lua (%d+%.%d+)")
print("Detected Lua version: " .. (lua_version or "unknown"))

-- Add multiple possible LuaRocks paths
local possible_paths = {
  "C:/Users/Dev/scoop/apps/luarocks/current/rocks/share/lua/" .. (lua_version or "5.1"),
  "C:/Users/Dev/scoop/apps/luarocks/current/rocks/share/lua/5.4",
  "C:/Users/Dev/scoop/apps/luarocks/current/rocks/share/lua/5.1"
}

for _, path in ipairs(possible_paths) do
  package.path = package.path .. ";" .. path .. "/?.lua"
  package.path = package.path .. ";" .. path .. "/?/init.lua"
end

-- Mock for game global
_G.game = _G.game or {
  surfaces = {},
  forces = {
    ["player"] = {
      find_chart_tags = function() return {} end
    }
  },
  print = function(msg) print("[GAME] " .. tostring(msg)) end
}

-- Try to load LuaCov
local has_luacov = pcall(require, "luacov")
if has_luacov then
  print("LuaCov found and enabled")
else
  print("LuaCov not found. Coverage will not be collected.")
  print("Consider installing LuaCov with: luarocks install luacov")
end

-- Function to run a single test file
local function run_test_file(file_path)
  print("\n==== Running " .. file_path .. " ====")
  
  -- Clear any existing test framework state
  package.loaded["tests.test_framework"] = nil
  
  -- Load fresh test framework for this file
  local test_framework = require("tests.test_framework")
  
  local success, err = pcall(function()
    dofile(file_path)
  end)
  
  if not success then
    print("ERROR loading " .. file_path .. ": " .. tostring(err))
    return false
  end
  
  -- Run the tests using the framework
  local test_success = test_framework.run()
  return test_success
end

-- Get all test files
local function get_test_files()
  local files = {}
  local handle = io.popen('powershell "Get-ChildItem -Path tests -Name *_spec.lua"')
  if not handle then
    print("ERROR: Could not execute PowerShell command")
    return {}
  end
  
  for file in handle:lines() do
    table.insert(files, "tests\\" .. file)
  end
  handle:close()
  return files
end

-- Run all tests
print("==== Running All Tests ====")
local test_files = get_test_files()
local total_files = 0
local successful_files = 0

for _, file in ipairs(test_files) do
  total_files = total_files + 1
  local file_success = run_test_file(file)
  if file_success then 
    successful_files = successful_files + 1 
  end
end

print("\n==== Overall Test Summary ====")
print("Test files processed: " .. total_files)
print("Test files successful: " .. successful_files)
print("Test files failed: " .. (total_files - successful_files))

-- Generate coverage report if LuaCov was enabled
if has_luacov then
  print("\n==== Generating Coverage Report ====")
  local reporter = require("luacov.reporter")
  reporter.report()
  print("Coverage report generated in luacov.report.out")
  
  -- Try to run our coverage analyzer
  pcall(function()
    dofile("analyze_coverage.lua")
  end)
  
  -- Try to run the Python coverage formatter
  os.execute("python py_scripts\\generate_formatted_coverage.py")
end

print("\n==== Testing Complete ====")