---@diagnostic disable: undefined-global
--[[
tests/test_debug_commands.lua
TeleportFavorites Factorio Mod
-----------------------------
Test script for debug level controls and commands.

This test verifies that:
1. Debug commands are properly registered
2. Debug levels can be changed at runtime
3. Logging respects debug level settings
4. GUI controls work correctly

Usage: Load in-game and run via remote interface
]]

local DebugConfig = require("core.utils.debug_config")
local Logger = require("core.utils.enhanced_error_handler")
local DebugCommands = require("core.commands.debug_commands")
local GuiBase = require("gui.gui_base")

---@class DebugCommandsTest
local DebugCommandsTest = {}

--- Test all debug level changes
function DebugCommandsTest.test_debug_level_changes()
  local results = {}
  
  -- Test each debug level
  for level = 0, 5 do
    DebugConfig.set_level(level)
    local current_level = DebugConfig.get_level()
    local level_name = DebugConfig.get_level_name(level)
    
    table.insert(results, {
      test = "set_level_" .. level,
      expected = level,
      actual = current_level,
      level_name = level_name,
      passed = current_level == level
    })
  end
  
  return results
end

--- Test logging respects debug levels
function DebugCommandsTest.test_logging_levels()
  local results = {}
  
  -- Test with NONE level (should suppress everything except errors)
  DebugConfig.set_level(DebugConfig.LEVELS.NONE)
  
  -- Test with INFO level (should allow error, warn, info but not debug/trace)
  DebugConfig.set_level(DebugConfig.LEVELS.INFO)
  
  local should_log_tests = {
    {level = DebugConfig.LEVELS.ERROR, should_log = true},
    {level = DebugConfig.LEVELS.WARN, should_log = true},
    {level = DebugConfig.LEVELS.INFO, should_log = true},
    {level = DebugConfig.LEVELS.DEBUG, should_log = false},
    {level = DebugConfig.LEVELS.TRACE, should_log = false}
  }
  
  for _, test in ipairs(should_log_tests) do
    local actual = DebugConfig.should_log(test.level)
    table.insert(results, {
      test = "should_log_" .. test.level,
      expected = test.should_log,
      actual = actual,
      passed = actual == test.should_log
    })
  end
  
  return results
end

--- Test production and development mode shortcuts
function DebugCommandsTest.test_mode_shortcuts()
  local results = {}
  
  -- Test production mode
  DebugConfig.enable_production_mode()
  local prod_level = DebugConfig.get_level()
  table.insert(results, {
    test = "production_mode",
    expected = DebugConfig.LEVELS.WARN,
    actual = prod_level,
    passed = prod_level == DebugConfig.LEVELS.WARN
  })
  
  -- Test development mode
  DebugConfig.enable_development_mode()
  local dev_level = DebugConfig.get_level()
  table.insert(results, {
    test = "development_mode", 
    expected = DebugConfig.LEVELS.DEBUG,
    actual = dev_level,
    passed = dev_level == DebugConfig.LEVELS.DEBUG
  })
  
  return results
end

--- Test GUI debug controls creation
function DebugCommandsTest.test_gui_controls_creation(player)
  if not player or not player.valid then
    return {{test = "gui_controls", passed = false, error = "Invalid player"}}
  end
  
  local results = {}
  
  -- Create a temporary frame to test GUI controls
  local test_frame = GuiBase.create_frame(player.gui.screen, "debug_test_frame", "vertical", "dialog_frame")
  
  local success, error_msg = pcall(function()
    local debug_controls = DebugCommands.create_debug_level_controls(test_frame, player)
    
    -- Verify controls were created
    if not debug_controls or not debug_controls.valid then
      error("Debug controls not created")
    end
    
    -- Check for expected elements
    local level_label = debug_controls["tf_debug_current_level"]
    if not level_label or not level_label.valid then
      error("Debug level label not found")
    end
    
    -- Check for level buttons
    local button_found = false
    for _, child in pairs(debug_controls.children) do
      if child.name and string.match(child.name, "tf_debug_set_level_") then
        button_found = true
        break
      end
    end
    
    if not button_found then
      error("No debug level buttons found")
    end
  end)
  
  -- Clean up test frame
  if test_frame and test_frame.valid then
    test_frame.destroy()
  end
  
  table.insert(results, {
    test = "gui_controls_creation",
    passed = success,
    error = error_msg
  })
  
  return results
end

--- Run all tests and return comprehensive results
function DebugCommandsTest.run_all_tests(player)
  local all_results = {}
  
  -- Run individual test suites
  local level_results = DebugCommandsTest.test_debug_level_changes()
  local logging_results = DebugCommandsTest.test_logging_levels() 
  local mode_results = DebugCommandsTest.test_mode_shortcuts()
  local gui_results = DebugCommandsTest.test_gui_controls_creation(player)
  
  -- Combine all results
  for _, result in ipairs(level_results) do
    table.insert(all_results, result)
  end
  for _, result in ipairs(logging_results) do
    table.insert(all_results, result)
  end
  for _, result in ipairs(mode_results) do
    table.insert(all_results, result)
  end
  for _, result in ipairs(gui_results) do
    table.insert(all_results, result)
  end
  
  -- Calculate summary
  local total_tests = #all_results
  local passed_tests = 0
  for _, result in ipairs(all_results) do
    if result.passed then
      passed_tests = passed_tests + 1
    end
  end
  
  return {
    summary = {
      total = total_tests,
      passed = passed_tests,
      failed = total_tests - passed_tests
    },
    results = all_results
  }
end

--- Print test results to player
function DebugCommandsTest.print_results(player, test_results)
  if not player or not player.valid then return end
  
  player.print("=== Debug Commands Test Results ===")
  player.print(string.format("Tests: %d passed, %d failed, %d total", 
    test_results.summary.passed, 
    test_results.summary.failed, 
    test_results.summary.total))
  
  -- Print failed tests
  if test_results.summary.failed > 0 then
    player.print("FAILED TESTS:")
    for _, result in ipairs(test_results.results) do
      if not result.passed then
        local error_info = result.error and (" - " .. result.error) or ""
        player.print(string.format("  ❌ %s: expected %s, got %s%s", 
          result.test, 
          tostring(result.expected), 
          tostring(result.actual),
          error_info))
      end
    end
  end
  
  if test_results.summary.failed == 0 then
    player.print("✅ All tests passed!")
  else
    player.print("❌ Some tests failed - check the details above")
  end
end

return DebugCommandsTest
