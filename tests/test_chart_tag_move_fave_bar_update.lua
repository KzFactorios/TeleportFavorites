--[[
Test: Chart Tag Move and Favorites Bar Update
=============================================

Test to verify that when a chart tag is moved, the favorites bar is properly
updated to reflect the new GPS coordinates.

Manual Test Steps:
1. Start the game and load a save
2. Create a chart tag at position A (e.g., [100, 100])
3. Add this chart tag to favorites (right-click tag, select "Add to Favorites")
4. Verify the favorite appears in the favorites bar with correct position
5. Move the chart tag to position B (e.g., [200, 200]) by dragging it
6. Check the debug logs for GPS update messages:
   - "PlayerFavorites updating GPS coordinates"
   - "Updating favorite GPS coordinates" 
   - "Chart tag GPS update - rebuilding favorites bars"
   - "Rebuilding favorites bar for GPS update"
7. Verify the favorites bar is visually updated with the new position
8. Click the favorite button to teleport
9. Verify teleportation goes to the NEW position (200, 200), not the old one (100, 100)

Expected Results:
- Debug logs should show GPS coordinates being updated from old to new position
- Favorites bar should be rebuilt after the chart tag move
- Favorite button should show updated GPS coordinates in tooltip
- Clicking the favorite should teleport to the NEW position, not the old one
- All players with this location favorited should have their bars updated

This test verifies the fix for: 
- Favorites not updating GPS coordinates when chart tags are moved
- Favorites bar not being rebuilt after GPS updates
- Teleportation going to old position instead of new position after tag move

Debug Commands:
/tf-debug-level 5  -- Enable detailed debug logging
/tf-data-viewer    -- Open data viewer to inspect favorite GPS coordinates
]]

-- This is a manual test file - no automated test code needed
-- The test must be performed in-game to verify GPS update behavior

return true
