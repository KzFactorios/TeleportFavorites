-- test_button_values.lua
-- This test file validates that we're handling button values correctly

local ErrorHandler = require("core.utils.error_handler")

-- Factorio button values (these are constants, not defines):
-- defines.mouse_button_type.left = left click
-- defines.mouse_button_type.right = right click
-- defines.mouse_button_type.middle = middle click

local function log_button_values()
  -- Print to player
  game.print("Button type validation:")
  game.print("defines.mouse_button_type.left = " .. defines.mouse_button_type.left .. " (should be 1)")
  game.print("defines.mouse_button_type.right = " .. defines.mouse_button_type.right .. " (should be 2)")
  game.print("defines.mouse_button_type.middle = " .. defines.mouse_button_type.middle .. " (should be 3)")
  
  -- Log for debugging
  ErrorHandler.debug_log("[BUTTON TEST] Button type constants", {
    left = defines.mouse_button_type.left,
    right = defines.mouse_button_type.right,
    middle = defines.mouse_button_type.middle,
    defines_matches_value = defines.mouse_button_type.left == 1 and 
                           defines.mouse_button_type.right == 2 and
                           defines.mouse_button_type.middle == 3
  })
end

return {
  log_button_values = log_button_values
}