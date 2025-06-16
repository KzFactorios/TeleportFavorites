
-- Test suite for terrain protection system
local ChartTagUtils = require("core.utils.chart_tag_utils")

local TerrainProtectionTests = {}

-- Test protected area calculation with default radius
function TerrainProtectionTests.test_calculate_protected_area()
  local position = { x = 10, y = 20 }
  local protected_area = ChartTagUtils.calculate_protected_area(position)
  
  assert(protected_area ~= nil, "Protected area should not be nil")
  assert(protected_area.left_top.x == 7, "Left boundary should be position.x - 3")
  assert(protected_area.left_top.y == 17, "Top boundary should be position.y - 3")
  assert(protected_area.right_bottom.x == 13, "Right boundary should be position.x + 3")
  assert(protected_area.right_bottom.y == 23, "Bottom boundary should be position.y + 3")
  
  print("[TEST PASS] Protected area calculation works correctly")
end

-- Test protection radius constants
function TerrainProtectionTests.test_protection_constants()
  local Constants = require("constants")
  
  assert(Constants.settings.TERRAIN_PROTECTION_MIN == 0, "Min protection should be 0")
  assert(Constants.settings.TERRAIN_PROTECTION_MAX == 9, "Max protection should be 9")
  assert(Constants.settings.TERRAIN_PROTECTION_DEFAULT == 3, "Default protection should be 3")
  
  print("[TEST PASS] Protection radius constants are correctly configured")
end

-- Run all terrain protection tests
function TerrainProtectionTests.run_all_tests()
  print("=== TERRAIN PROTECTION SYSTEM TESTS ===")
  
  TerrainProtectionTests.test_calculate_protected_area()
  TerrainProtectionTests.test_protection_constants()
  
  print("=== ALL TERRAIN PROTECTION TESTS COMPLETED ===")
end

return TerrainProtectionTests
