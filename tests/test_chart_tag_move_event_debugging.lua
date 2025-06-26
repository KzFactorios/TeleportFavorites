--[[
Test: Chart Tag Move Event Debugging
===================================

This test helps debug why favorites are not being updated when chart tags are moved.

Manual Test Steps:
1. Enable maximum debug logging: `/tf-debug-level 5`
2. Create a chart tag at a specific location (e.g., [100, 100])
3. Add this chart tag to favorites (right-click → "Add to Favorites")
4. Note the GPS coordinates in the favorite button tooltip
5. Move the chart tag by dragging it to a new location (e.g., [200, 200])
6. Check the console/log for these debug messages:

Expected Debug Messages When Moving a Chart Tag:
- "Chart tag modified event received"
- "Chart tag GPS extraction results"
- "Extracting GPS from chart tag modification event"
- "New GPS extracted from tag position"
- "Old GPS extracted from old_position" OR "No old_position in event"
- "Chart tag modified - updating favorites GPS"
- "PlayerFavorites updating GPS coordinates"
- "Chart tag GPS update - rebuilding favorites bars"

Key Questions to Answer:
1. Is the on_chart_tag_modified event being triggered at all?
2. Does the event provide old_position data when dragging tags?
3. Are new_gps and old_gps being extracted correctly?
4. Is the GPS update logic being called?
5. Is the favorites bar being rebuilt?

If ANY of these debug messages are missing, that indicates where the problem is:

Missing "Chart tag modified event received":
- The event is not being registered or triggered
- Check event registration in event_registration_dispatcher.lua

Missing GPS extraction messages:
- The GPS extraction logic has a bug
- Check ChartTagModificationHelpers.extract_gps()

Missing "No old_position in event":
- Factorio is not providing old_position for drag operations
- This is likely the root cause - Factorio may not send old_position for moves

Missing GPS update messages:
- The conditions for updating are not being met
- old_gps and new_gps might be nil or the same

After Testing:
- Check if favorite button tooltip shows the NEW GPS coordinates
- Try teleporting via the favorite - does it go to the old or new position?
- Use Data Viewer to inspect the actual stored GPS coordinates in favorites
]]

-- This is a manual debugging test - no automated code needed
return true
