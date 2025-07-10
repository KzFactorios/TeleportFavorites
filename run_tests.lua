-- Test runner for TeleportFavorites using Busted
-- Runs tests with proper busted integration and generates coverage

-- Add current directory to package path to make local modules findable
package.path = "./?.lua;" .. package.path

print("Lua version: " .. _VERSION)

-- Try to load busted
local busted_available = false
local success, result = pcall(require, "busted")
if success then
  busted_available = true
  print("Using Busted test framework")
else
  print("Busted not available, attempting to use busted command line")
end

-- Mock require to handle dependencies when running tests
local original_require = require
_G.require = function(module_name)
  -- If it's a test module, load it with our test framework
  if module_name:match("^tests%.") then
    return original_require(module_name)
  end
  
  -- Try to load the real module first
  local load_success, load_result = pcall(original_require, module_name)
  if load_success then
    return load_result
  end
  
  -- If it fails, check if we have a mock for it
  local mock_path = "tests.mocks." .. module_name:gsub("%.", "_")
  local mock_success, mock_result = pcall(original_require, mock_path)
  if mock_success then
    print("Using mock for: " .. module_name)
    return mock_result
  end
  
  -- Return an empty table as fallback
  print("WARNING: No module found for: " .. module_name)
  return {}
end

-- Simple mock for LuaCov so tests that require it don't fail
_G.luacov = {
  tick = function() end,
  pause = function() end,
  resume = function() end
}

-- Function to run a specific test file using busted command line
local function run_test_file(file_path)
  local test_name = file_path:match("tests[/\\](.+)%.lua") or file_path
  print("\n==== Running test: " .. test_name .. " ====")
  
  -- Use busted command line to run the test with coverage
  local cmd = string.format('busted --coverage --verbose "%s"', file_path)
  local exit_code = os.execute(cmd)
  
  if exit_code == 0 then
    print("Test passed: " .. test_name)
    return true
  else
    print("Test failed: " .. test_name)
    return false
  end
end

-- Function to run all tests using busted
local function run_all_tests_with_busted()
  print("\n==== Running All Tests with Busted ====")
  
  -- Run busted on the tests directory with coverage
  local cmd = 'busted --coverage --verbose tests/'
  local exit_code = os.execute(cmd)
  
  return exit_code == 0
end

print("\n==== Running TeleportFavorites Tests ====")

-- Run a specific test if specified
if arg[1] then
  local arg1 = arg[1] --[[@as string]]
  local test_file = "tests\\" .. arg1
  if not arg1:match("%.lua$") then
    test_file = test_file .. ".lua"
  end
  local success = run_test_file(test_file)
  os.exit(success and 0 or 1)
else
  -- Run all tests using busted
  local all_passed = run_all_tests_with_busted()
  
  -- Print coverage information
  if pcall(function() dofile("analyze_coverage.lua") end) then
    print("\nCoverage analysis completed.")
  else
    print("\n==== Coverage Information ====")
    print("For detailed coverage information, please use:")
    print("1. Run busted --coverage tests/")
    print("2. Run luacov to generate the report")
    print("3. Run lua analyze_coverage.lua to see a summary")
  end
  
  print("\n==== Tests Completed ====")
  os.exit(all_passed and 0 or 1)
end
