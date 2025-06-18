---@diagnostic disable: undefined-global
--[[
TeleportFavorites - Natural Position System Test
===============================================
Tests the natural position uniqueness system that prevents position conflicts
through chart tag reuse and GPS-keyed storage without separate collision detection.

Usage:
1. Load Factorio with TeleportFavorites mod
2. Open console and run: /c require("tests.test_natural_position_system")
3. Follow the manual testing steps provided in output

Based on the natural system described in COLLISION_SYSTEM_TESTING_GUIDE.md
]]

local ChartTagUtils = require("core.utils.chart_tag_utils")
local Cache = require("core.cache.cache")
local GPSUtils = require("core.utils.gps_utils")
local Tag = require("core.tag.tag")
local ErrorHandler = require("core.utils.error_handler")
local GameHelpers = require("core.utils.game_helpers")

local function test_natural_position_system()
  local player = game.get_player(1)
  if not player or not player.valid then
    print("❌ No valid player found for testing")
    return
  end

  local surface = player.surface
  if not surface or not surface.valid then
    print("❌ No valid surface found for testing")
    return
  end

  GameHelpers.player_print(player, "🧪 Testing Natural Position System...")
  GameHelpers.player_print(player, "This system prevents duplicates through chart tag reuse and GPS-keyed storage.")

  -- Test positions
  local test_pos_1 = {x = 100, y = 100}
  local test_pos_2 = {x = 200, y = 200}
  local test_gps_1 = GPSUtils.gps_from_map_position(test_pos_1, surface.index)
  local test_gps_2 = GPSUtils.gps_from_map_position(test_pos_2, surface.index)

  -- ===== TEST 1: Chart Tag Reuse Detection =====
  GameHelpers.player_print(player, "📍 Test 1: Chart Tag Reuse Detection")
  
  -- Create first chart tag
  local first_spec = ChartTagUtils.build_chart_tag_spec(test_pos_1, "First Tag", nil, player.name)
  local first_tag = ChartTagUtils.safe_add_chart_tag(player.force, surface, first_spec, player)
  
  if first_tag and first_tag.valid then
    GameHelpers.player_print(player, "✅ First chart tag created successfully")
    
    -- Try to create second tag at same position - should reuse existing
    local second_spec = ChartTagUtils.build_chart_tag_spec(test_pos_1, "Updated Tag", nil, player.name)
    local second_tag = ChartTagUtils.safe_add_chart_tag(player.force, surface, second_spec, player)
    
    if second_tag and second_tag.valid and second_tag == first_tag then
      GameHelpers.player_print(player, "✅ Chart tag reuse WORKING - existing tag updated")
    else
      GameHelpers.player_print(player, "❌ Chart tag reuse FAILED - new tag created instead of reuse")
    end
  else
    GameHelpers.player_print(player, "❌ Failed to create first chart tag")
  end

  -- ===== TEST 2: Tag GPS Storage Uniqueness =====
  GameHelpers.player_print(player, "🏷️ Test 2: Tag GPS Storage Natural Uniqueness")
  
  -- Create Tag object at first GPS
  local tag_data = {
    gps = test_gps_1,
    text = "Test Tag Object",
    chart_tag = first_tag
  }
  
  local first_tag_obj = Tag.create_from_data(tag_data, player)
  if first_tag_obj then
    -- Store in cache (natural GPS-keyed storage)
    Cache.set_tag(player, test_gps_1, first_tag_obj)
    GameHelpers.player_print(player, "✅ First Tag object stored successfully")
    
    -- Try to store another Tag at same GPS - should replace naturally
    local updated_data = {
      gps = test_gps_1,
      text = "Updated Tag Object",
      chart_tag = first_tag
    }
    local second_tag_obj = Tag.create_from_data(updated_data, player)
    Cache.set_tag(player, test_gps_1, second_tag_obj)
    
    -- Check that GPS storage only has one tag
    local stored_tag = Cache.get_tag(player, test_gps_1)
    if stored_tag and stored_tag.text == "Updated Tag Object" then
      GameHelpers.player_print(player, "✅ Tag GPS uniqueness WORKING - tag naturally replaced")
    else
      GameHelpers.player_print(player, "❌ Tag GPS uniqueness FAILED - tag not replaced properly")
    end
  else
    GameHelpers.player_print(player, "❌ Failed to create first Tag object")
  end

  -- ===== TEST 3: System Integration =====
  GameHelpers.player_print(player, "🔗 Test 3: Chart Tag and Tag System Integration")
  
  -- Create chart tag and Tag at different position
  local third_spec = ChartTagUtils.build_chart_tag_spec(test_pos_2, "Integration Test", nil, player.name)
  local third_chart_tag = ChartTagUtils.safe_add_chart_tag(player.force, surface, third_spec, player)
  
  if third_chart_tag and third_chart_tag.valid then
    local integration_data = {
      gps = test_gps_2,
      text = "Integration Tag",
      chart_tag = third_chart_tag
    }
    local integration_tag = Tag.create_from_data(integration_data, player)
    Cache.set_tag(player, test_gps_2, integration_tag)
    
    GameHelpers.player_print(player, "✅ Different position: Both chart tag and Tag created successfully")
  else
    GameHelpers.player_print(player, "❌ Integration test failed")
  end

  GameHelpers.player_print(player, "🛡️ Natural position uniqueness testing complete!")
  GameHelpers.player_print(player, "The system uses chart tag reuse and GPS-keyed storage for natural conflict prevention.")
end

-- Auto-run the test when required
test_natural_position_system()
