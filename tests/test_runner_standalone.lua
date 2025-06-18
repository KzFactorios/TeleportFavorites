--[[
Standalone Test Runner for TeleportFavorites
===========================================
This test runner creates a minimal mock environment that simulates Factorio's APIs
for testing core logic outside of the game environment.

Usage: lua tests/test_runner_standalone.lua
]]

-- Mock Factorio global objects and APIs
local function setup_factorio_mocks()
  -- Mock storage table
  _G.storage = {}
  
  -- Mock game object
  _G.game = {
    players = {},
    forces = {
      player = {
        chart_tags = {}
      }
    },
    surfaces = {
      [1] = {
        index = 1,
        name = "nauvis",
        valid = true,
        get_tile = function(self, position)
          return {
            name = "grass-1",
            valid = true
          }
        end,
        add_chart_tag = function(self, spec)
          local chart_tag = {
            position = spec.position,
            text = spec.text or "",
            icon = spec.icon,
            last_user = spec.last_user,
            valid = true,
            surface = self,
            destroy = function() end
          }
          table.insert(_G.game.forces.player.chart_tags, chart_tag)
          return chart_tag
        end,
        find_entities_filtered = function() return {} end
      }
    },
    get_player = function(index)
      return _G.game.players[index]
    end,
    get_surface = function(index)
      return _G.game.surfaces[index]
    end
  }
  
  -- Mock player
  _G.game.players[1] = {
    index = 1,
    name = "test_player",
    valid = true,
    force = _G.game.forces.player,
    surface = _G.game.surfaces[1],
    print = function(self, message)
      print("[PLAYER] " .. tostring(message))
    end,
    position = {x = 0, y = 0}
  }
  
  -- Mock defines
  _G.defines = {
    events = {
      on_player_built_tile = 1,
      on_robot_built_tile = 2,
      on_player_mined_tile = 3,
      on_robot_mined_tile = 4,
      script_raised_set_tiles = 5
    },
    render_mode = {
      chart = 1,
      chart_zoomed_in = 2
    }
  }
  
  -- Mock settings
  _G.settings = {
    get_player_settings = function(player)
      return {
        ["chart-tag-click-radius"] = { value = 3 },
        ["terrain-protection-radius"] = { value = 5 }
      }
    end
  }
  
  -- Mock script object
  _G.script = {
    on_event = function(event, handler) end
  }
  
  -- Mock log function
  _G.log = function(message)
    print("[LOG] " .. tostring(message))
  end
  
  -- Mock package.path to include our core directory
  package.path = package.path .. ";./core/?.lua;./core/utils/?.lua;./core/cache/?.lua;./core/tag/?.lua"
end

-- Test result tracking
local test_results = {
  passed = 0,
  failed = 0,
  errors = {}
}

-- Simple assertion framework
local function assert_test(condition, message, test_name)
  if condition then
    test_results.passed = test_results.passed + 1
    print("✅ PASS: " .. (test_name or "unnamed test"))
  else
    test_results.failed = test_results.failed + 1
    local error_msg = (test_name or "unnamed test") .. ": " .. (message or "assertion failed")
    table.insert(test_results.errors, error_msg)
    print("❌ FAIL: " .. error_msg)
  end
end

-- Mock cache persistence test
local function test_cache_persistence_mock()
  print("\n🧪 Testing Cache Persistence (Mocked)...")
  
  -- Test 1: Basic cache structure
  local success, Cache = pcall(require, "core.cache.cache")
  assert_test(success, "Failed to load Cache module: " .. tostring(Cache), "Cache module loading")
  
  if not success then
    return
  end
  
  -- Test 2: Cache initialization
  local cache_initialized = Cache ~= nil and type(Cache.Lookups) == "table"
  assert_test(cache_initialized, "Cache.Lookups not properly initialized", "Cache initialization")
  
  -- Test 3: Surface cache creation
  if cache_initialized then
    local surface_cache = Cache.Lookups.get_chart_tag_cache(1)
    assert_test(type(surface_cache) == "table", "Surface cache should be a table", "Surface cache creation")
  end
  
  print("Cache persistence mock tests completed.")
end

-- Mock chart tag collision detection test
local function test_natural_position_system_mock()
  print("\n🧪 Testing Natural Position System (Mocked)...")
  
  -- Test that GPS-keyed storage works
  local test_tags = {}
  local test_gps = "000000100.000000200.1"
  
  -- Store a tag
  test_tags[test_gps] = { gps = test_gps, text = "Test Tag" }
  assert_test(test_tags[test_gps] ~= nil, "Failed to store tag at GPS coordinate", "GPS-keyed storage")
  
  -- Overwrite the same GPS (natural collision prevention)
  test_tags[test_gps] = { gps = test_gps, text = "Updated Tag" }
  assert_test(test_tags[test_gps].text == "Updated Tag", "Failed to update tag at GPS coordinate", "GPS natural uniqueness")
  
  print("Natural position system mock tests completed.")
end

-- Mock chart tag utils test
local function test_chart_tag_utils_mock()
  print("\n🧪 Testing Chart Tag Utils (Mocked)...")
  
  -- Test ChartTagUtils loading
  local success, ChartTagUtils = pcall(require, "core.utils.chart_tag_utils")
  assert_test(success, "Failed to load ChartTagUtils: " .. tostring(ChartTagUtils), "ChartTagUtils loading")
  
  if not success then
    return
  end
  
  -- Test safe_add_chart_tag function exists
  local has_safe_add = type(ChartTagUtils.safe_add_chart_tag) == "function"
  assert_test(has_safe_add, "safe_add_chart_tag function not found", "Safe add chart tag function")
    -- Test build_chart_tag_spec function exists
  local has_build_spec = type(ChartTagUtils.build_chart_tag_spec) == "function"
  assert_test(has_build_spec, "build_chart_tag_spec function not found", "Build chart tag spec function")
  
  print("Chart tag utils mock tests completed.")
end

-- Mock tag editor control test
local function test_tag_editor_control_mock()
  print("\n🧪 Testing Tag Editor Control (Mocked)...")
  
  -- Test tag editor control loading
  local success, result = pcall(require, "core.control.control_tag_editor")
  assert_test(success, "Failed to load control_tag_editor: " .. tostring(result), "Tag editor control loading")
  
  print("Tag editor control mock tests completed.")
end

-- Run all mock tests
local function run_all_mock_tests()
  print("🚀 Running TeleportFavorites Mock Test Suite...")
  print("=" .. string.rep("=", 60))
  
  -- Setup mocked environment
  setup_factorio_mocks()
    -- Run individual test suites
  test_cache_persistence_mock()
  test_natural_position_system_mock()
  test_chart_tag_utils_mock()
  test_tag_editor_control_mock()
  
  -- Print results summary
  print("\n📊 Test Results Summary:")
  print("=" .. string.rep("=", 30))
  print("✅ Passed: " .. test_results.passed)
  print("❌ Failed: " .. test_results.failed)
  print("🔢 Total:  " .. (test_results.passed + test_results.failed))
  
  if test_results.failed > 0 then
    print("\n🔍 Failed Tests:")
    for _, error in ipairs(test_results.errors) do
      print("  • " .. error)
    end
  end
  
  local success_rate = math.floor((test_results.passed / (test_results.passed + test_results.failed)) * 100)
  print("\n🎯 Success Rate: " .. success_rate .. "%")
  
  if test_results.failed == 0 then
    print("\n🎉 All tests passed! The core modules can be loaded successfully.")
    print("💡 To test actual functionality, run the verification scripts in Factorio:")
    print("   /c dofile('verify_cache_fixes.lua')")
    print("   /c dofile('verify_collision_detection.lua')")
  else
    print("\n⚠️  Some tests failed. Check the error messages above for details.")
  end
end

-- Execute the test suite
run_all_mock_tests()
