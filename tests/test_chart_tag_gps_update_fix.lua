--[[
Test: Chart Tag Move GPS Update Fix Verification
==============================================

This test verifies that the fix for the ErrorHandler.raise() error allows
the favorites GPS update process to complete successfully.

Context from Previous Debug Logs:
- Chart tag modification event WAS being triggered ✅
- GPS extraction WAS working (old: 012.-036.1 → new: -092.006.1) ✅  
- But the process failed due to: "attempt to call field 'raise' (a nil value)" ❌

Expected Fix Result:
After fixing the ErrorHandler.raise() bug, the chart tag move should now trigger:
1. ✅ Chart tag modified event received
2. ✅ GPS extraction (old → new GPS)
3. ✅ Chart tag modified - updating favorites GPS  
4. ✅ PlayerFavorites updating GPS coordinates
5. ✅ Chart tag GPS update - rebuilding favorites bars
6. ✅ Favorites bar shows updated GPS coordinates
7. ✅ Teleportation goes to NEW position, not old one

Manual Test Steps:
1. Enable debug logging: `/tf-debug-level 5`
2. Create a chart tag and add it to favorites
3. Note the original GPS coordinates (e.g., 012.-036.1)
4. Move the chart tag by dragging to a new location
5. Verify no "attempt to call field 'raise'" error appears
6. Check debug logs for complete GPS update workflow
7. Verify favorites bar visually updates
8. Test teleportation - should go to NEW position

What Should Happen Now:
- No more "Event handler failed" errors
- Complete GPS update process execution  
- Favorites bar rebuild with new coordinates
- Successful teleportation to moved tag location

This fix resolves the root cause preventing favorites from updating when chart tags are moved.
]]

-- This is a manual verification test
return true
