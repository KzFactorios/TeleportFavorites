-- Run all tests and generate coverage report
-- Add current directory, parent directory, and tests root to package path
package.path = "./?.lua;../?.lua;../../?.lua;" .. package.path

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
  package.loaded["test_framework"] = nil
  
  -- Ensure the test framework path is available from the test file's perspective
  local original_path = package.path
  package.path = "./infrastructure/?.lua;./?.lua;../infrastructure/?.lua;../?.lua;" .. package.path
  
  -- Load fresh test framework for this file
  local test_framework = require("test_framework")
  
  -- Adjust path for running from infrastructure directory  
  local actual_path = file_path
  if file_path:match("^specs/") then
    actual_path = file_path  -- specs directory is at the same level when running from tests directory
  end
  
  local success, err = pcall(function()
    dofile(actual_path)
  end)
  
  -- Restore original path
  package.path = original_path
  
  if not success then
    print("ERROR loading " .. file_path .. ": " .. tostring(err))
    return false, 0, 0  -- file_success, tests_passed, tests_failed
  end
  
  -- Run the tests using the framework and get detailed results
  local test_success, tests_passed, tests_failed = test_framework.run()
  
  return test_success, tests_passed or 0, tests_failed or 0
end

-- Get all test files from specs directory
local function get_test_files()
  local files = {}
  -- Try multiple path approaches
  local possible_commands = {
    'dir /b "specs\\*_spec.lua" 2>nul',  -- From tests directory
    'dir /b "..\\specs\\*_spec.lua" 2>nul'  -- From infrastructure directory
  }
  
  for _, cmd in ipairs(possible_commands) do
    local handle = io.popen(cmd)
    if handle then
      for file in handle:lines() do
        -- Only add valid lua files, skip empty lines or error messages
        if file and type(file) == "string" and file:match("%.lua$") then
          -- Use specs/ prefix for files found
          table.insert(files, "specs/" .. file)
        end
      end
      handle:close()
      -- If we found files, use them
      if #files > 0 then
        break
      end
    end
  end
  
  return files
end

-- Run all tests
print("==== Running All Tests ====")
local test_files = get_test_files()
local total_files = 0
local successful_files = 0
local total_tests_passed = 0
local total_tests_failed = 0

for _, file in ipairs(test_files) do
  total_files = total_files + 1
  local file_success, tests_passed, tests_failed = run_test_file(file)
  
  total_tests_passed = total_tests_passed + (tests_passed or 0)
  total_tests_failed = total_tests_failed + (tests_failed or 0)
  
  if file_success then 
    successful_files = successful_files + 1 
  end
end

print("\n==== Overall Test Summary ====")
print("Test files processed: " .. total_files)
print("Test files successful: " .. successful_files)
print("Test files failed: " .. (total_files - successful_files))
print("Total tests passed: " .. total_tests_passed)
print("Total tests failed: " .. total_tests_failed)
print("Total tests run: " .. (total_tests_passed + total_tests_failed))

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
  os.execute("python \"V:\\Fac2orios\\2_Gemini\\mods\\TeleportFavorites\\.scripts\\generate_formatted_coverage.py\"")
end

print("\n==== Testing Complete ====")
