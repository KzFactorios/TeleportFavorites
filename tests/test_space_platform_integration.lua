-- test_space_platform_integration.lua
-- Test file for space platform detection integration

local PositionUtils = require("core.utils.position_utils")

---@class SpacePlatformIntegrationTests
local SpacePlatformIntegrationTests = {}

--- Mock player for testing (simulates space platform player)
local function create_mock_space_platform_player()
  return {
    valid = true,
    name = "test_player",
    surface = {
      valid = true,
      index = 2, -- Space platform surface
      name = "space-platform-1"
    },
    position = {x = 100, y = 100},
    print = function(msg) end -- Mock print function
  }
end

--- Mock player for testing (simulates regular surface player)
local function create_mock_regular_player()
  return {
    valid = true,
    name = "test_player",
    surface = {
      valid = true,
      index = 1, -- Regular surface
      name = "nauvis"
    },
    position = {x = 100, y = 100},
    print = function(msg) end -- Mock print function
  }
end

--- Mock surface for testing
local function create_mock_space_surface()
  return {
    valid = true,
    index = 2,
    name = "space-platform-1",
    get_tile = function(x, y)
      return {
        valid = true,
        name = "space-platform-foundation", -- Space tile
        prototype = {
          collision_mask = {}
        }
      }
    end
  }
end

--- Mock surface for testing (regular surface)
local function create_mock_regular_surface()
  return {
    valid = true,
    index = 1,
    name = "nauvis",
    get_tile = function(x, y)
      return {
        valid = true,
        name = "grass-1", -- Regular land tile
        prototype = {
          collision_mask = {}
        }
      }
    end
  }
end

--- Test space platform detection
function SpacePlatformIntegrationTests.test_space_platform_detection()
  local space_player = create_mock_space_platform_player()
  local regular_player = create_mock_regular_player()
  
  -- Test space platform detection
  local is_space_platform = PositionUtils.is_on_space_platform(space_player)
  local is_regular_surface = PositionUtils.is_on_space_platform(regular_player)
  
  print("Space platform detection test:")
  print("  Space platform player: " .. tostring(is_space_platform))
  print("  Regular surface player: " .. tostring(is_regular_surface))
  
  return is_space_platform == true and is_regular_surface == false
end

--- Test space tile validation with space platform context
function SpacePlatformIntegrationTests.test_space_tile_validation()
  local space_surface = create_mock_space_surface()
  local regular_surface = create_mock_regular_surface()
  local space_player = create_mock_space_platform_player()
  local regular_player = create_mock_regular_player()
  
  local test_position = {x = 100, y = 100}
  
  -- Test space tile walkability on space platform
  local space_walkable = PositionUtils.is_walkable_position(space_surface, test_position, space_player)
  
  -- Test space tile walkability on regular surface
  local regular_walkable = PositionUtils.is_walkable_position(space_surface, test_position, regular_player)
  
  print("Space tile validation test:")
  print("  Space tile on space platform: " .. tostring(space_walkable))
  print("  Space tile on regular surface: " .. tostring(regular_walkable))
  
  return space_walkable == true and regular_walkable == false
end

--- Test position validation with space platform integration
function SpacePlatformIntegrationTests.test_position_validation_integration()
  local space_player = create_mock_space_platform_player()
  local regular_player = create_mock_regular_player()
  
  local space_position = {x = 100, y = 100}
  
  -- Test tag position validation (should allow space tiles on space platforms)
  local space_valid = PositionUtils.is_valid_tag_position(space_player, space_position, true)
  local regular_valid = PositionUtils.is_valid_tag_position(regular_player, space_position, true)
  
  print("Position validation integration test:")
  print("  Space position for space platform player: " .. tostring(space_valid))
  print("  Space position for regular player: " .. tostring(regular_valid))
  
  -- On space platforms, space tiles should be valid for tagging
  -- On regular surfaces, space tiles should not be valid for tagging
  return space_valid == true and regular_valid == false
end

--- Run all tests
function SpacePlatformIntegrationTests.run_all_tests()
  print("=== Space Platform Integration Tests ===")
  
  local test1_result = SpacePlatformIntegrationTests.test_space_platform_detection()
  local test2_result = SpacePlatformIntegrationTests.test_space_tile_validation()
  local test3_result = SpacePlatformIntegrationTests.test_position_validation_integration()
  
  local all_passed = test1_result and test2_result and test3_result
  
  print("\n=== Test Results ===")
  print("Space platform detection: " .. (test1_result and "PASS" or "FAIL"))
  print("Space tile validation: " .. (test2_result and "PASS" or "FAIL"))
  print("Position validation integration: " .. (test3_result and "PASS" or "FAIL"))
  print("Overall: " .. (all_passed and "ALL TESTS PASSED" or "SOME TESTS FAILED"))
  
  return all_passed
end

return SpacePlatformIntegrationTests
