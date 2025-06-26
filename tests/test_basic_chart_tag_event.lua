-- test_basic_chart_tag_event.lua
-- Simple test to verify chart tag movement events are firing
local handlers = require("core.events.handlers")
local ErrorHandler = require("core.utils.error_handler")

local function test_basic_event_logging()
  ErrorHandler.debug_log("=== BASIC CHART TAG EVENT TEST ===")
  
  -- Check if the event handler exists
  if handlers.on_chart_tag_modified then
    ErrorHandler.debug_log("Chart tag modified handler exists")
  else
    ErrorHandler.debug_log("ERROR: Chart tag modified handler does NOT exist")
  end
  
  -- Test with a mock player
  local test_player = game.players[1]
  if not test_player then
    ErrorHandler.debug_log("No player found for testing")
    return
  end
  
  ErrorHandler.debug_log("Player found for testing", {
    player_name = test_player.name,
    player_valid = test_player.valid
  })
  
  ErrorHandler.debug_log("=== END BASIC CHART TAG EVENT TEST ===")
end

-- Return the test function
return {
  test_basic_event_logging = test_basic_event_logging
}
