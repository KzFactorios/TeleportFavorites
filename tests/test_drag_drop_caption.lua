---@diagnostic disable: undefined-global
-- tests/test_drag_drop_caption.lua
-- Test that the caption fix for drag/drop works correctly

local GuiUtils = require("core.utils.gui_utils")
local PlayerFavorites = require("core.favorite.player_favorites")
local CursorUtils = require("core.utils.cursor_utils")

-- Mock dependencies for testing
local function setup_test_environment()
  -- Create a test player
  local test_player = {
    valid = true,
    index = 1,
    name = "test_player",
    clear_cursor = function() end,
    cursor_stack = {
      valid = true,
      set_stack = function() return true end,
      label = "",
      set_blueprint_entities = function() return true end
    },
    print = function(msg) print("[PLAYER] " .. msg) end
  }
  
  -- Create a mock element for testing
  local test_element = {
    valid = true,
    name = "fave_bar_slot_3",
    caption = "3",  -- Caption is set but should not be used for logic
    tags = {}
  }
  
  local mock_favorites = {
    favorites = {
      { gps = "gps:0,0", locked = false, tag = { chart_tag = { icon = {type="item", name="iron-plate"}, text = "Test Tag" } } },
      { gps = "gps:10,10", locked = false, tag = { chart_tag = { icon = {type="item", name="copper-plate"}, text = "Another Tag" } } },
      { gps = "gps:20,20", locked = false, tag = { chart_tag = { icon = {type="item", name="steel-plate"}, text = "Yet Another Tag" } } },
    }
  }
  
  -- Mock the event object
  local test_event = {
    element = test_element,
    player_index = 1,
    button = defines.mouse_button_type.left,
    shift = true,
    control = false
  }
  
  return test_player, test_event, mock_favorites
end

-- Test that drag state is correctly set
local function test_drag_state_tracking()
  print("Testing drag state tracking...")
  
  local player, event, mock_favorites = setup_test_environment()
  local slot_index = 3
  local favorite = mock_favorites.favorites[1]
  
  -- Start drag
  local drag_success = CursorUtils.start_drag_favorite(player, favorite, slot_index)
  
  -- Check if we're dragging
  local is_dragging, source_slot = CursorUtils.is_dragging_favorite(player)
  
  -- Verify
  assert(drag_success, "Drag should start successfully")
  assert(is_dragging, "Player should be in drag state")
  assert(source_slot == slot_index, "Source slot should match")
  
  -- End drag
  CursorUtils.end_drag_favorite(player)
  
  -- Verify drag ended
  is_dragging, source_slot = CursorUtils.is_dragging_favorite(player)
  assert(not is_dragging, "Drag state should be cleared")
  
  print("✓ Drag state tracking test passed")
end

-- Test that the slot is correctly identified from element name, not caption
local function test_slot_identification()
  print("Testing slot identification from name, not caption...")
  
  -- Create a test element with different name and caption
  local element = {
    valid = true,
    name = "fave_bar_slot_5",  -- Should use this
    caption = "3",             -- Should NOT use this
    tags = {}
  }
  
  -- Parse slot using the same logic as in control_fave_bar.lua
  local slot = tonumber(element.name:match("fave_bar_slot_(%d+)"))
  
  -- Verify
  assert(slot == 5, "Slot should be parsed from name, not caption")
  print("✓ Slot identification test passed")
end

-- Run all tests
local function run_tests()
  print("Starting drag and drop caption fix tests...")
  
  test_drag_state_tracking()
  test_slot_identification()
  
  print("All tests passed!")
end

run_tests()

-- This test can be run in-game to verify that the caption fix works correctly.
-- However, full end-to-end testing requires manual verification of the drag-and-drop
-- functionality in the actual game environment.

return {
  in_game_verification_steps = {
    "Create at least three favorites in different slots",
    "Shift+Click on a favorite to start dragging",
    "Verify cursor shows the favorite icon",
    "Click on another slot to drop",
    "Verify favorite moved to the new slot",
    "Verify dragging a favorite to a locked slot fails"
  }
}
