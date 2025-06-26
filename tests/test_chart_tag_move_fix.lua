--[[
Test: Chart Tag Move Fix - No Destruction
=========================================

This test verifies that the fix prevents chart tags from being destroyed 
when moved, ensuring favorites continue to work with the moved chart tag.

Context - Previous Problem:
- Chart tag modification was destroying the moved chart tag ❌
- After moving, no chart tag existed at new location ❌  
- Favorites showed fallback icons instead of chart tag icons ❌
- Data Viewer showed no chart tags in lookup data ❌

Expected Fix Result:
After fixing the chart tag destruction issue:
1. ✅ Chart tag modification event processes correctly
2. ✅ GPS coordinates update in favorites (old → new GPS)
3. ✅ Chart tag remains valid at NEW location (not destroyed)
4. ✅ Favorites bar shows correct chart tag icon (not fallback)
5. ✅ Data Viewer shows chart tag exists in lookup data
6. ✅ Teleportation works to new location

Manual Test Steps:
1. Enable debug logging: `/tf-debug-level 5`
2. Create a chart tag and add it to favorites
3. Verify chart tag icon appears in favorites bar
4. Open Data Viewer → Lookup Data tab → verify chart tag exists
5. Move the chart tag by dragging to a new location
6. Check debug logs - should see:
   - "Using modified chart tag from event" 
   - "Chart tag modification completed - no cleanup needed"
   - NO "Starting tag destruction" message
7. Verify chart tag still exists at new location on map
8. Verify favorites bar still shows chart tag icon (not fallback)
9. Open Data Viewer → verify chart tag exists at new GPS coordinates
10. Test teleportation - should go to new location

Success Indicators:
- No chart tag destruction during move
- Chart tag visible at new location on map
- Favorites bar shows proper chart tag icon
- Data Viewer shows chart tag in lookup data
- Teleportation works correctly

This fix ensures chart tag moves update favorites without destroying the chart tag.
]]

-- This is a manual verification test
return true
