---@diagnostic disable: undefined-global
--[[
tests/test_dev_performance_monitor.lua
TeleportFavorites Factorio Mod
-----------------------------
Test suite for development performance monitoring system.

Tests:
- Performance measurement accuracy
- Cache operation tracking
- Memory snapshot functionality
- Dashboard display functionality
- Integration with debug levels
]]

local DevPerformanceMonitor = require("core.utils.dev_performance_monitor")
local DebugConfig = require("core.utils.debug_config")
local GameHelpers = require("core.utils.game_helpers")

---@class DevPerformanceMonitorTest
local DevPerformanceMonitorTest = {}

--- Test performance operation measurement
---@param player LuaPlayer Player to run tests for
---@return table test_result Test results
function DevPerformanceMonitorTest.test_operation_measurement(player)
  local test_name = "operation_measurement"
  
  -- Ensure debug level is high enough for monitoring
  local original_level = DebugConfig.get_level()
  DebugConfig.set_level(DebugConfig.LEVELS.DEBUG)
  
  -- Initialize monitoring
  DevPerformanceMonitor.initialize()
  
  -- Test measuring a simple operation
  local result = DevPerformanceMonitor.measure_operation("test_operation", function()
    -- Simulate some work
    local sum = 0
    for i = 1, 1000 do
      sum = sum + i
    end
    return sum
  end, {test_context = "unit_test"})
  
  -- Verify result is correct
  local expected_result = 500500 -- Sum of 1 to 1000
  local measurement_works = (result == expected_result)
  
  -- Get performance summary
  local summary = DevPerformanceMonitor.get_performance_summary()
  local has_operations = summary.recent_operations_count > 0
  
  -- Restore original debug level
  DebugConfig.set_level(original_level)
  
  return {
    test = test_name,
    passed = measurement_works and has_operations,
    details = {
      measurement_correct = measurement_works,
      operations_recorded = has_operations,
      expected_result = expected_result,
      actual_result = result,
      operations_count = summary.recent_operations_count
    }
  }
end

--- Test cache operation tracking
---@param player LuaPlayer Player to run tests for
---@return table test_result Test results
function DevPerformanceMonitorTest.test_cache_operations(player)
  local test_name = "cache_operations"
  
  -- Ensure debug level is high enough
  local original_level = DebugConfig.get_level()
  DebugConfig.set_level(DebugConfig.LEVELS.DEBUG)
  
  DevPerformanceMonitor.initialize()
  DevPerformanceMonitor.reset_data() -- Start fresh
  
  -- Record some cache operations
  DevPerformanceMonitor.record_cache_operation("hit", "test_cache")
  DevPerformanceMonitor.record_cache_operation("hit", "test_cache")
  DevPerformanceMonitor.record_cache_operation("miss", "test_cache")
  
  local summary = DevPerformanceMonitor.get_performance_summary()
  
  -- Verify cache statistics
  local expected_hits = 2
  local expected_misses = 1
  local expected_lookups = 3
  local expected_hit_rate = 2/3
  
  local hits_correct = summary.cache_stats.hits == expected_hits
  local misses_correct = summary.cache_stats.misses == expected_misses
  local lookups_correct = summary.cache_stats.lookups == expected_lookups
  local hit_rate_correct = math.abs(summary.cache_hit_rate - expected_hit_rate) < 0.01
  
  DebugConfig.set_level(original_level)
  
  return {
    test = test_name,
    passed = hits_correct and misses_correct and lookups_correct and hit_rate_correct,
    details = {
      hits_correct = hits_correct,
      misses_correct = misses_correct,
      lookups_correct = lookups_correct,
      hit_rate_correct = hit_rate_correct,
      actual_stats = summary.cache_stats,
      actual_hit_rate = summary.cache_hit_rate
    }
  }
end

--- Test memory snapshot functionality
---@param player LuaPlayer Player to run tests for
---@return table test_result Test results
function DevPerformanceMonitorTest.test_memory_snapshots(player)
  local test_name = "memory_snapshots"
  
  local original_level = DebugConfig.get_level()
  DebugConfig.set_level(DebugConfig.LEVELS.DEBUG)
  
  DevPerformanceMonitor.initialize()
  DevPerformanceMonitor.reset_data()
  
  -- Take a memory snapshot
  DevPerformanceMonitor.take_memory_snapshot()
  
  local summary = DevPerformanceMonitor.get_performance_summary()
  local snapshots_taken = summary.memory_snapshots_count > 0
  
  DebugConfig.set_level(original_level)
  
  return {
    test = test_name,
    passed = snapshots_taken,
    details = {
      snapshots_count = summary.memory_snapshots_count,
      snapshots_taken = snapshots_taken
    }
  }
end

--- Test dashboard display functionality
---@param player LuaPlayer Player to run tests for
---@return table test_result Test results
function DevPerformanceMonitorTest.test_dashboard_display(player)
  local test_name = "dashboard_display"
  
  local original_level = DebugConfig.get_level()
  DebugConfig.set_level(DebugConfig.LEVELS.DEBUG)
  
  DevPerformanceMonitor.initialize()
  
  -- Try to show dashboard (should not error)
  local dashboard_success = pcall(function()
    DevPerformanceMonitor.show_performance_dashboard(player)
  end)
  
  DebugConfig.set_level(original_level)
  
  return {
    test = test_name,
    passed = dashboard_success,
    details = {
      dashboard_displayed = dashboard_success
    }
  }
end

--- Test debug level integration
---@param player LuaPlayer Player to run tests for  
---@return table test_result Test results
function DevPerformanceMonitorTest.test_debug_level_integration(player)
  local test_name = "debug_level_integration"
  
  -- Test with debug level too low (should not monitor)
  DebugConfig.set_level(DebugConfig.LEVELS.WARN)
  
  local result_low = DevPerformanceMonitor.measure_operation("test_low_level", function()
    return 42
  end)
  
  local summary_low = DevPerformanceMonitor.get_performance_summary()
  local monitoring_disabled = not summary_low.active
  
  -- Test with debug level high enough (should monitor)
  DebugConfig.set_level(DebugConfig.LEVELS.DEBUG)
  DevPerformanceMonitor.initialize()
  
  local result_high = DevPerformanceMonitor.measure_operation("test_high_level", function()
    return 84
  end)
  
  local summary_high = DevPerformanceMonitor.get_performance_summary()
  local monitoring_enabled = summary_high.active
  
  return {
    test = test_name,
    passed = monitoring_disabled and monitoring_enabled and result_low == 42 and result_high == 84,
    details = {
      low_level_disabled = monitoring_disabled,
      high_level_enabled = monitoring_enabled,
      results_correct = result_low == 42 and result_high == 84
    }
  }
end

--- Run all performance monitoring tests
---@param player LuaPlayer Player to run tests for
---@return table results Complete test results
function DevPerformanceMonitorTest.run_all_tests(player)
  local tests = {
    DevPerformanceMonitorTest.test_operation_measurement,
    DevPerformanceMonitorTest.test_cache_operations,
    DevPerformanceMonitorTest.test_memory_snapshots,
    DevPerformanceMonitorTest.test_dashboard_display,
    DevPerformanceMonitorTest.test_debug_level_integration
  }
  
  local results = {
    total_tests = #tests,
    passed_tests = 0,
    failed_tests = 0,
    test_results = {}
  }
  
  for _, test_func in ipairs(tests) do
    local test_result = test_func(player)
    table.insert(results.test_results, test_result)
    
    if test_result.passed then
      results.passed_tests = results.passed_tests + 1
    else
      results.failed_tests = results.failed_tests + 1
    end
  end
  
  return results
end

--- Print test results to player
---@param player LuaPlayer Player to show results to
---@param results table Test results from run_all_tests
function DevPerformanceMonitorTest.print_results(player, results)
  GameHelpers.player_print(player, "=== DevPerformanceMonitor Test Results ===")
  GameHelpers.player_print(player, "Total tests: " .. results.total_tests)
  GameHelpers.player_print(player, "Passed: " .. results.passed_tests)
  GameHelpers.player_print(player, "Failed: " .. results.failed_tests)
  GameHelpers.player_print(player, "")
  
  for _, test_result in ipairs(results.test_results) do
    local status = test_result.passed and "✓ PASS" or "✗ FAIL"
    GameHelpers.player_print(player, status .. " - " .. test_result.test)
    
    if not test_result.passed then
      GameHelpers.player_print(player, "  Details: " .. serpent.line(test_result.details))
    end
  end
  
  GameHelpers.player_print(player, "==========================================")
end

return DevPerformanceMonitorTest
