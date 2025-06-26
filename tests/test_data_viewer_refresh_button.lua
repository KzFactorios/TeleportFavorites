--[[
Test: Data Viewer Refresh Button Display
========================================

Test to verify that the Data Viewer refresh button displays as a sprite-button
with the correct refresh icon instead of a text button.

Manual Test Steps:
1. Start the game and load a save
2. Open the Data Viewer GUI with the keyboard shortcut (default: CONTROL + D)
3. Verify that the refresh button appears in the tabs row
4. Check that the refresh button displays as a sprite button with a refresh icon (circular arrow)
5. Check that the refresh button has the correct tooltip: "Refresh data display"
6. Click the refresh button to ensure it functions properly
7. Verify the refresh button has appropriate styling (32x32 size, proper spacing)

Expected Results:
- Refresh button should be a sprite-button with the utility/refresh icon
- Button should inherit from tf_slot_button style (32x32 pixels with proper padding)
- Button should appear as a slot button consistent with other UI elements
- Button should have a tooltip when hovered
- Button should function when clicked (triggers data refresh)
- Button should be visually consistent with font size buttons (+ and -)

This test verifies the fix for: 
- Refresh button not displaying as a slot button
- Missing refresh icon (was showing text "Refresh" instead)
- Proper use of sprite enums and GuiBase conventions
- Consistent styling with tf_slot_button parent
]]

-- This is a manual test file - no automated test code needed
-- The test must be performed in-game to verify visual and functional aspects

return true
