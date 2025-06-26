-- Test: Cursor Icon During Drag Operations
-- Tests that the iron plate icon appears in the cursor during drag operations

local CursorUtils = require("core.utils.cursor_utils")
local Cache = require("core.cache.cache")
local FavoriteUtils = require("core.favorite.favorite")

local function test_cursor_icon_during_drag()
  log("=== CURSOR ICON TEST ===")
  
  -- Get test player
  local player = game.players[1]
  if not player then
    log("❌ No player found for testing")
    return
  end
  
  -- Create a test favorite
  local test_favorite = {
    type = "tag",
    gps = "100.100.1",
    locked = false,
    tag = {
      chart_tag = {
        text = "Test Location",
        position = {x = 100, y = 100}
      },
      gps = "100.100.1"
    }
  }
  
  log("🔄 Testing cursor icon during drag...")
  
  -- Clear cursor first
  player.clear_cursor()
  log("Cursor cleared - should be empty: " .. tostring(not player.cursor_stack.valid_for_read))
  
  -- Check if cursor_ghost is available
  ---@diagnostic disable-next-line: undefined-field
  log("Initial cursor_ghost: " .. tostring(player.cursor_ghost or "none"))
  
  -- Start drag operation
  local success = CursorUtils.start_drag_favorite(player, test_favorite, 1)
  log("Start drag success: " .. tostring(success))
  
  -- Check if cursor now has an item or ghost
  local has_cursor_item = player.cursor_stack.valid_for_read
  log("Cursor has item after drag start: " .. tostring(has_cursor_item))
  
  -- Check cursor_ghost status
  ---@diagnostic disable-next-line: undefined-field
  log("Cursor ghost after drag start: " .. tostring(player.cursor_ghost or "none"))
  
  -- Check if cursor now has an item
  local has_cursor_item = player.cursor_stack.valid_for_read
  log("Cursor has item after drag start: " .. tostring(has_cursor_item))
  
  if has_cursor_item then
    local cursor_item = player.cursor_stack.name
    local cursor_count = player.cursor_stack.count
    log("Cursor item: " .. tostring(cursor_item) .. " (count: " .. tostring(cursor_count) .. ")")
    
    if cursor_item == "blueprint" then
      log("✅ Cursor item correctly set to blueprint")
    else
      log("❌ Cursor item incorrect - expected blueprint, got: " .. tostring(cursor_item))
    end
  else
    -- Check if cursor_ghost is set instead
    ---@diagnostic disable-next-line: undefined-field
    local cursor_ghost = player.cursor_ghost
    if cursor_ghost == "blueprint" then
      log("✅ Cursor ghost correctly set to blueprint")
    else
      log("❌ No cursor item or ghost found after drag start")
    end
  end
  
  -- Check drag state
  local is_dragging, source_slot = CursorUtils.is_dragging_favorite(player)
  log("Is dragging: " .. tostring(is_dragging) .. ", source slot: " .. tostring(source_slot))
  
  -- End drag operation
  local end_success = CursorUtils.end_drag_favorite(player)
  log("End drag success: " .. tostring(end_success))
  
  -- Check cursor is cleared
  local cursor_cleared = not player.cursor_stack.valid_for_read
  log("Cursor cleared after drag end: " .. tostring(cursor_cleared))
  
  -- Check drag state is reset
  local is_still_dragging = CursorUtils.is_dragging_favorite(player)
  log("Still dragging after end: " .. tostring(is_still_dragging))
  
  log("=== CURSOR ICON TEST COMPLETE ===")
end

-- Register test command
commands.add_command("test_cursor_icon", "Test cursor icon during drag operations", function(command)
  test_cursor_icon_during_drag()
end)

log("Cursor icon test loaded. Use /test_cursor_icon to run the test.")
