--[[
tests/test_chart_tag_move_favorites_fix.md
TeleportFavorites Factorio Mod
-----------------------------
Test Instructions for Chart Tag Move Favorites Fix

ISSUE IDENTIFIED:
The chart tag modification handler was calling normalize_and_replace_chart_tag() 
on ALL tag moves, even when normalization wasn't needed. This was destroying 
the original chart tag and creating a new one, breaking all GPS references 
and favorites bar updates.

FIX APPLIED:
Modified the on_chart_tag_modified handler in core/events/handlers.lua to:
1. Check if normalization is needed using PositionUtils.needs_normalization()
2. Only call normalize_and_replace_chart_tag() for fractional coordinates
3. For normal moves, preserve the original chart tag and update GPS references

IN-GAME TEST INSTRUCTIONS:

Test 1: Normal Tag Move (Should preserve chart tag)
1. Create a chart tag at whole number coordinates (e.g., 100, 200)
2. Add it to favorites using the favorites bar
3. Drag the chart tag to a new whole number position (e.g., 150, 250)
4. Verify the favorites bar still shows the tag and teleport still works
5. Check that the GPS coordinates updated in the favorite

Test 2: Fractional Coordinate Normalization (Should replace chart tag)
1. Use console command to create a chart tag with fractional coordinates:
   /c game.player.force.add_chart_tag(game.player.surface, {position = {x = 300.7, y = 400.3}, text = "Test Fractional"})
2. The mod should automatically normalize this to whole numbers
3. Verify the chart tag position becomes (301, 400) or similar

Test 3: Multiple Moves (Should preserve references)
1. Create a chart tag and add to favorites
2. Move it multiple times to different positions
3. Each move should update the GPS in favorites
4. Teleport should always work to the current position

Expected Behavior:
- Normal tag moves preserve the original chart tag object
- Favorites bar updates correctly after moves
- GPS coordinates stay in sync
- Only fractional coordinates trigger chart tag replacement
- No "invalid chart tag" errors in debug logs

If the test fails:
- Check debug logs for "Chart tag move without fractional coordinates" messages
- Verify that chart_tag.valid remains true after normal moves
- Check that favorite GPS coordinates match the new tag position
]]
