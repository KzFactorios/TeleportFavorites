# Chart Tag Move Favorites Fix - Summary

## Problem Identified
The favorites bar stopped working after moving chart tags because the `on_chart_tag_modified` event handler was incorrectly calling `normalize_and_replace_chart_tag()` on ALL chart tag moves, regardless of whether normalization was needed.

## Root Cause Analysis
1. **Unnecessary Tag Destruction**: The `normalize_and_replace_chart_tag()` function destroys the original chart tag and creates a new one
2. **Broken References**: When a chart tag is destroyed, all references to it (including those in favorites) become invalid
3. **Incorrect Trigger**: The function was being called for all tag moves, but should only be called for tags with fractional coordinates

## Technical Details
- **File Modified**: `core/events/handlers.lua` - `on_chart_tag_modified()` function
- **Key Change**: Added conditional check using `PositionUtils.needs_normalization()` before calling normalization
- **Logic Split**: 
  - Normal moves (whole number coordinates): Preserve original chart tag, update GPS references
  - Fractional coordinates: Normalize by destroying/recreating chart tag

## Code Changes

### Before (Problematic)
```lua
local new_chart_tag, position_pair = TagEditorEventHelpers.normalize_and_replace_chart_tag(chart_tag, player)
if new_chart_tag then
  -- Always destroyed and recreated chart tag
end
```

### After (Fixed)
```lua
local needs_normalization = PositionUtils.needs_normalization(chart_tag.position)

if needs_normalization then
  -- Only normalize fractional coordinates
  local new_chart_tag, position_pair = TagEditorEventHelpers.normalize_and_replace_chart_tag(chart_tag, player)
  -- Handle normalized GPS coordinates
else
  -- Normal move - preserve original chart tag
  ChartTagModificationHelpers.update_tag_and_cleanup(old_gps, new_gps, event, player)
  ChartTagModificationHelpers.update_favorites_gps(old_gps, new_gps, player)
end
```

## Expected Behavior After Fix
1. ✅ Normal chart tag moves preserve the original chart tag object
2. ✅ Favorites continue to work after tag moves  
3. ✅ GPS coordinates are properly updated in all data structures
4. ✅ Only fractional coordinates trigger chart tag replacement
5. ✅ No more "invalid chart tag" errors in debug logs

## Testing Instructions
1. Create a chart tag and add it to favorites
2. Drag the tag to a new position
3. Verify the favorites bar updates with the new coordinates
4. Test teleportation to confirm it works at the new location
5. Move the tag multiple times to test persistence

This fix resolves the critical issue where moving chart tags would break the favorites system.
