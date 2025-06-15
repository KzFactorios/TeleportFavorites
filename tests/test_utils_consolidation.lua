--[[
test_utils_consolidation.lua
TeleportFavorites Factorio Mod - Utils Consolidation Test
--------------------------------------------------------
Tests for the consolidated utility modules to ensure all functionality works correctly.

This test verifies:
- All consolidated modules load without errors
- Key functions from each consolidated module work correctly
- Integration between consolidated modules works as expected
- Backward compatibility is maintained
]]

-- Import all consolidated modules
local PositionUtils = require("core.utils.position_utils")
local GPSUtils = require("core.utils.gps_utils")
local CollectionUtils = require("core.utils.collection_utils")
local ChartTagUtils = require("core.utils.chart_tag_utils")
local ValidationUtils = require("core.utils.validation_utils")
local GuiUtils = require("core.utils.gui_utils")
local Utils = require("core.utils.utils")

---@class UtilsConsolidationTest
local UtilsConsolidationTest = {}

-- ========================================
-- MODULE LOADING TESTS
-- ========================================

--- Test that all consolidated modules load without errors
function UtilsConsolidationTest.test_modules_load()
  local modules = {
    { name = "PositionUtils", module = PositionUtils },
    { name = "GPSUtils", module = GPSUtils },
    { name = "CollectionUtils", module = CollectionUtils },
    { name = "ChartTagUtils", module = ChartTagUtils },
    { name = "ValidationUtils", module = ValidationUtils },
    { name = "GuiUtils", module = GuiUtils },
    { name = "Utils", module = Utils }
  }
  
  for _, mod in ipairs(modules) do
    assert(mod.module, "Module " .. mod.name .. " failed to load")
    assert(type(mod.module) == "table", "Module " .. mod.name .. " is not a table")
  end
  
  print("✓ All consolidated modules loaded successfully")
end

-- ========================================
-- POSITION UTILS TESTS
-- ========================================

--- Test PositionUtils functionality
function UtilsConsolidationTest.test_position_utils()
  -- Test position normalization
  local normalized = PositionUtils.normalize_position({ x = 10.5, y = -5.7 })
  assert(normalized.x == 10 and normalized.y == -6, "Position normalization failed")
  
  -- Test position validation
  local valid = PositionUtils.is_valid_position({ x = 100, y = 200 })
  assert(valid == true, "Position validation failed")
  
  -- Test invalid position
  local invalid = PositionUtils.is_valid_position({ x = "invalid", y = 200 })
  assert(invalid == false, "Invalid position should be rejected")
  
  print("✓ PositionUtils tests passed")
end

-- ========================================
-- GPS UTILS TESTS  
-- ========================================

--- Test GPSUtils functionality
function UtilsConsolidationTest.test_gps_utils()
  -- Test GPS string creation
  local gps = GPSUtils.gps_from_map_position({ x = 100, y = 200 }, 1)
  assert(type(gps) == "string", "GPS string creation failed")
  assert(string.find(gps, "100"), "GPS should contain x coordinate")
  
  -- Test GPS parsing
  local position = GPSUtils.map_position_from_gps(gps)
  assert(position and position.x == 100 and position.y == 200, "GPS parsing failed")
  
  print("✓ GPSUtils tests passed")
end

-- ========================================
-- COLLECTION UTILS TESTS
-- ========================================

--- Test CollectionUtils functionality  
function UtilsConsolidationTest.test_collection_utils()
  -- Test table operations
  local test_table = { a = 1, b = 2, c = 3 }
  local keys = CollectionUtils.table_keys(test_table)
  assert(type(keys) == "table" and #keys == 3, "Table keys extraction failed")
  
  -- Test array operations
  local test_array = { 1, 2, 3, 4, 5 }
  local filtered = CollectionUtils.filter_array(test_array, function(x) return x > 3 end)
  assert(#filtered == 2, "Array filtering failed")
  
  print("✓ CollectionUtils tests passed")
end

-- ========================================
-- VALIDATION UTILS TESTS
-- ========================================

--- Test ValidationUtils functionality
function UtilsConsolidationTest.test_validation_utils()
  -- Test GPS validation
  local valid_gps = "000000100.000000200.1"
  local gps_valid, _ = ValidationUtils.validate_gps_string(valid_gps)
  assert(gps_valid == true, "GPS validation failed for valid GPS")
  
  -- Test invalid GPS
  local invalid_gps = "invalid.gps.string"
  local gps_invalid, _ = ValidationUtils.validate_gps_string(invalid_gps)
  assert(gps_invalid == false, "GPS validation should reject invalid GPS")
  
  -- Test position validation
  local pos_valid, _ = ValidationUtils.validate_position_structure({ x = 100, y = 200 })
  assert(pos_valid == true, "Position validation failed")
  
  print("✓ ValidationUtils tests passed")
end

-- ========================================
-- UNIFIED FACADE TESTS
-- ========================================

--- Test that the unified facade provides access to all functions
function UtilsConsolidationTest.test_unified_facade()
  -- Test that Utils provides access to key functions from all modules
  assert(Utils.PositionUtils, "Utils should provide PositionUtils")
  assert(Utils.GPSUtils, "Utils should provide GPSUtils") 
  assert(Utils.CollectionUtils, "Utils should provide CollectionUtils")
  assert(Utils.ValidationUtils, "Utils should provide ValidationUtils")
  
  -- Test that functions are accessible through the facade
  local gps = Utils.GPSUtils.gps_from_map_position({ x = 50, y = 75 }, 1)
  assert(type(gps) == "string", "GPS function not accessible through facade")
  
  print("✓ Unified facade tests passed")
end

-- ========================================
-- INTEGRATION TESTS
-- ========================================

--- Test integration between consolidated modules
function UtilsConsolidationTest.test_module_integration()
  -- Test GPS + Position integration
  local position = { x = 123, y = 456 }
  local gps = GPSUtils.gps_from_map_position(position, 1)
  local parsed_position = GPSUtils.map_position_from_gps(gps)
  local normalized = PositionUtils.normalize_position(parsed_position)
  
  assert(normalized.x == 123 and normalized.y == 456, "GPS-Position integration failed")
  
  -- Test GPS + Validation integration
  local valid, parsed, error = ValidationUtils.validate_and_parse_gps(gps)
  assert(valid == true, "GPS validation integration failed")
  assert(parsed and parsed.x == 123, "GPS parsing integration failed")
  
  print("✓ Module integration tests passed")
end

-- ========================================
-- PERFORMANCE TESTS
-- ========================================

--- Test performance of consolidated modules vs original scattered functions
function UtilsConsolidationTest.test_performance()
  local iterations = 1000
  local start_time = game and game.tick or 0
  
  -- Test repeated GPS operations
  for i = 1, iterations do
    local gps = GPSUtils.gps_from_map_position({ x = i, y = i * 2 }, 1)
    local position = GPSUtils.map_position_from_gps(gps)
    local validated = ValidationUtils.validate_position_structure(position)
  end
  
  local end_time = game and game.tick or 0
  local duration = end_time - start_time
  
  print(string.format("✓ Performance test completed in %d ticks (%d iterations)", duration, iterations))
end

-- ========================================
-- TEST RUNNER
-- ========================================

--- Run all consolidation tests
function UtilsConsolidationTest.run_all_tests()
  print("========================================")
  print("UTILS CONSOLIDATION TEST SUITE")
  print("========================================")
  
  local tests = {
    { name = "Module Loading", func = UtilsConsolidationTest.test_modules_load },
    { name = "PositionUtils", func = UtilsConsolidationTest.test_position_utils },
    { name = "GPSUtils", func = UtilsConsolidationTest.test_gps_utils },
    { name = "CollectionUtils", func = UtilsConsolidationTest.test_collection_utils },
    { name = "ValidationUtils", func = UtilsConsolidationTest.test_validation_utils },
    { name = "Unified Facade", func = UtilsConsolidationTest.test_unified_facade },
    { name = "Module Integration", func = UtilsConsolidationTest.test_module_integration },
    { name = "Performance", func = UtilsConsolidationTest.test_performance }
  }
  
  local passed = 0
  local failed = 0
  
  for _, test in ipairs(tests) do
    local success, error_msg = pcall(test.func)
    if success then
      passed = passed + 1
    else
      failed = failed + 1
      print(string.format("✗ %s test FAILED: %s", test.name, error_msg or "Unknown error"))
    end
  end
  
  print("========================================")
  print(string.format("CONSOLIDATION TEST RESULTS: %d passed, %d failed", passed, failed))
  print("========================================")
  
  return failed == 0
end

return UtilsConsolidationTest
