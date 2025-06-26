-- test_tag_editor_gps_update_on_move.lua
-- Test to verify tag editor GPS is updated when the tag being edited is moved
local handlers = require("core.events.handlers")
local Cache = require("core.cache.cache")
local ErrorHandler = require("core.utils.error_handler")

local function test_tag_editor_gps_update()
  ErrorHandler.debug_log("=== TESTING TAG EDITOR GPS UPDATE ON MOVE ===")
  
  local test_player = game.players[1]
  if not test_player then
    ErrorHandler.debug_log("No player found for testing")
    return
  end
  
  -- Test setup: Create mock tag editor data
  local old_gps = "[gps=100,100,nauvis]"
  local new_gps = "[gps=200,200,nauvis]"
  
  local tag_editor_data = Cache.create_tag_editor_data({
    gps = old_gps,
    text = "Test Tag",
    icon = "",
    is_favorite = true
  })
  
  Cache.set_tag_editor_data(test_player, tag_editor_data)
  
  ErrorHandler.debug_log("Before tag move", {
    tag_editor_gps = tag_editor_data.gps,
    old_gps = old_gps,
    new_gps = new_gps
  })
  
  -- Simulate chart tag modification event
  local mock_event = {
    player_index = test_player.index,
    tag = {
      valid = true,
      position = {x = 200, y = 200},
      surface = test_player.surface,
      last_user = test_player
    },
    old_position = {x = 100, y = 100}
  }
  
  -- Call the handler
  handlers.on_chart_tag_modified(mock_event)
  
  -- Check if tag editor data was updated
  local updated_tag_editor_data = Cache.get_tag_editor_data(test_player)
  
  ErrorHandler.debug_log("After tag move", {
    updated_gps = updated_tag_editor_data and updated_tag_editor_data.gps or "nil",
    expected_new_gps = new_gps,
    gps_updated = updated_tag_editor_data and updated_tag_editor_data.gps == new_gps
  })
  
  if updated_tag_editor_data and updated_tag_editor_data.gps == new_gps then
    ErrorHandler.debug_log("✅ TEST PASSED: Tag editor GPS was updated correctly")
  else
    ErrorHandler.debug_log("❌ TEST FAILED: Tag editor GPS was not updated")
  end
  
  ErrorHandler.debug_log("=== END TAG EDITOR GPS UPDATE TEST ===")
end

return {
  test_tag_editor_gps_update = test_tag_editor_gps_update
}
