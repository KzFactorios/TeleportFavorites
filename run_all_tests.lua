-- Run all tests and generate coverage report
package.path = "./?.lua;" .. package.path

-- Add luacov paths to package.path (if available)
local lua_version = _VERSION:match("Lua (%d+%.%d+)")
local luarocks_path = "C:/Users/Dev/scoop/apps/luarocks/current/rocks/share/lua/" .. (lua_version or "5.1")
package.path = package.path .. ";" .. luarocks_path .. "/?.lua"

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

-- Create basic test framework functions
_G.describe = function(desc, fn)
  print("\nDESCRIBE: " .. desc)
  fn()
end

local before_each_fn = nil
_G.before_each = function(fn)
  before_each_fn = fn
end

_G.it = function(desc, fn)
  print("  IT: " .. desc)
  
  -- Run before_each if set
  if before_each_fn then
    pcall(before_each_fn)
  end
  
  -- Run the test
  local success, err = pcall(fn)
  if success then
    print("    ✓ PASS")
  else
    print("    ✗ FAIL: " .. tostring(err))
  end
end

-- Functions needed by tests
_G.are_same = function(a, b, msg)
  if a ~= b then
    error((msg or "Assertion failed: values not equal") .. "\nExpected: " .. tostring(a) .. "\nActual:   " .. tostring(b), 2)
  end
end

_G.is_true = function(v, msg)
  if not v then
    error((msg or "Assertion failed: value is not true") .. "\nActual: " .. tostring(v), 2)
  end
end

_G.is_nil = function(v, msg)
  if v ~= nil then
    error((msg or "Assertion failed: value is not nil") .. "\nActual: " .. tostring(v), 2)
  end
end

_G.has_error = function(fn, msg)
  local ok = pcall(fn)
  if ok then
    error((msg or "Assertion failed: function did not error as expected"), 2)
  end
end

-- Function to run a test file
local function run_test_file(file_path)
  print("\n==== Running " .. file_path .. " ====")
  
  -- Reset test environment (clean globals that might be set by previous tests)
  before_each_fn = nil
  
  local success, err = pcall(function()
    dofile(file_path)
  end)
  
  if not success then
    print("ERROR in " .. file_path .. ": " .. tostring(err))
    return false
  end
  
  return true
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
local tests_run = 0
local tests_passed = 0

for _, file in ipairs(test_files) do
  local passed = run_test_file(file)
  tests_run = tests_run + 1
  if passed then tests_passed = tests_passed + 1 end
end

print("\n==== Test Summary ====")
print("Tests run: " .. tests_run)
print("Tests passed: " .. tests_passed)
print("Tests failed: " .. (tests_run - tests_passed))

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
