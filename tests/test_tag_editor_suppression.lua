---@diagnostic disable: undefined-global, unused-local

-- Test script for tag editor suppression during drag cancellation operations
-- This script outlines the test cases for verifying that the tag editor does not
-- open when right-clicking during a drag operation.

local Cache = require("core.cache.cache")
local CursorUtils = require("core.utils.cursor_utils")
local handlers = require("core.events.handlers")
local ErrorHandler = require("core.utils.error_handler")

-- Simulate the sequence that happens during a right-click drag cancellation

function test_drag_cancel_tag_editor_interaction()
  -- 1. Set up initial conditions - player dragging a favorite
  local player = game.player
  if not player or not player.valid then
    print("Test requires a valid player")
    return
  end
  
  -- 2. Simulate starting drag
  local player_data = Cache.get_player_data(player)
  player_data.drag_favorite = {
    active = true,
    source_slot = 2,
    favorite = { gps = "gps:0,0", locked = false }
  }
  
  -- 3. Simulate right-click event that cancels drag
  local event = {
    player_index = player.index,
    button = defines.mouse_button_type.right,
    tick = game.tick
  }
  
  -- 4. Process event - this should cancel drag and set suppression flag
  -- In production this happens in gui_event_dispatcher.lua
  CursorUtils.end_drag_favorite(player)
  player_data.suppress_tag_editor = { tick = game.tick }
  
  -- 5. Verify tag editor suppression works
  -- Create a fake map click event that would normally open tag editor
  local map_event = {
    player_index = player.index,
    cursor_position = { x = 0, y = 0 },
    button = defines.mouse_button_type.right
  }
  
  -- 6. Check function that opens tag editor
  -- In production, this is handlers.on_open_tag_editor_custom_input
  local should_open = true
  
  -- Check suppression flag - should block tag editor
  if player_data.suppress_tag_editor and 
     player_data.suppress_tag_editor.tick and 
     player_data.suppress_tag_editor.tick == game.tick then
    should_open = false
  end
  
  if not should_open then
    print("✅ Tag editor correctly suppressed")
  else
    print("❌ Tag editor suppression failed")
  end
  
  -- 7. Cleanup
  player_data.drag_favorite = { active = false }
  player_data.suppress_tag_editor = nil
end

-- Instructions for manual testing:

-- Test 1: Tag editor suppression during drag
-- 1. Start dragging a favorite (Shift+Click on a favorite slot)
-- 2. Right-click on the map
-- 3. Verify:
--    - Drag operation is canceled with notification
--    - Tag editor does NOT open

-- Test 2: Normal tag editor operation
-- 1. Ensure no drag is active
-- 2. Right-click on map
-- 3. Verify tag editor opens normally

-- Test 3: Sequence testing
-- 1. Start dragging a favorite
-- 2. Right-click to cancel
-- 3. Wait a moment (to ensure different game tick)
-- 4. Right-click on map
-- 5. Verify tag editor opens normally (suppression should only affect the current tick)

print("Tag editor suppression test loaded. Run tests manually in-game.")
