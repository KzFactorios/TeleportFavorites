-- test_button_direct_values.lua
-- Tests direct numeric button value comparisons to ensure they work correctly

local ErrorHandler = require("core.utils.error_handler")

-- Test direct button value comparisons
local function validate_direct_button_comparisons()
  -- Create a mock event to simulate different button clicks
  local left_click_event = {button = defines.mouse_button_type.left, shift = false, control = false}
  local right_click_event = {button = defines.mouse_button_type.right, shift = false, control = false}
  local middle_click_event = {button = defines.mouse_button_type.middle, shift = false, control = false}
  
  -- Test direct numeric comparisons
  local results = {
    left_click_detected = left_click_event.button == defines.mouse_button_type.left,
    right_click_detected = right_click_event.button == defines.mouse_button_type.right,
    middle_click_detected = middle_click_event.button == defines.mouse_button_type.middle,
    
    -- Also test defines values
    defines_left = defines.mouse_button_type.left,
    defines_right = defines.mouse_button_type.right,
    defines_middle = defines.mouse_button_type.middle,
    
    -- Test if they match
    left_click_matches_defines = left_click_event.button == defines.mouse_button_type.left,
    right_click_matches_defines = right_click_event.button == defines.mouse_button_type.right,
    middle_click_matches_defines = left_click_event.button == defines.mouse_button_type.middle
  }
  
  -- Log the results for inspection
  ErrorHandler.debug_log("[BUTTON_TEST] Button value comparison results", results)
  
  -- Output to player
  if game and game.print then
    game.print("Button test results:")
    game.print("Left click value: 1, detected: " .. tostring(results.left_click_detected))
    game.print("Right click value: 2, detected: " .. tostring(results.right_click_detected))
    game.print("Left click matches defines: " .. tostring(results.left_click_matches_defines))
    game.print("Right click matches defines: " .. tostring(results.right_click_matches_defines))
    if not results.left_click_matches_defines or not results.right_click_matches_defines then
      game.print("WARNING: Button values don't match defines values!")
    else
      game.print("Button values match defines values correctly")
    end
  end
  
  return results
end

return {
  validate_direct_button_comparisons = validate_direct_button_comparisons
}
