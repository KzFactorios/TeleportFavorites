# Chart Tag Detection Tolerance Fix

## Issue Description
Users reported that right-clicking on existing chart tags' radius area failed to load the tag's location info. This was caused by overly strict tolerance settings in the chart tag detection system.

## Root Cause
The `CHART_TAG_CLICK_RADIUS` constant in `core/utils/chart_tag_utils.lua` was set to 1.0 tiles, which was too restrictive for user interactions. Users had to click very precisely on chart tag centers to trigger the tag editor.

## Solution
**File:** `v:\Fac2orios\2_Gemini\mods\TeleportFavorites\core\utils\chart_tag_utils.lua`

**Change:** Increased `CHART_TAG_CLICK_RADIUS` from `1.0` to `2.5` tiles

```lua
-- Before
local CHART_TAG_CLICK_RADIUS = 1.0

-- After  
local CHART_TAG_CLICK_RADIUS = 2.5
```

## Impact
- **150% increase** in detection area radius (from 1.0 to 2.5 tiles)
- Chart tags can now be detected when clicked up to 2.5 tiles away from center
- Improvement zone (1.0-2.5 tiles) solves the "missed clicks" issue
- Exact position clicks and nearby clicks still work as before
- Very distant clicks (>2.5 tiles) are still properly rejected to avoid false positives

## Testing
Created comprehensive test suite in `tests/test_chart_tag_detection_tolerance.lua` that validates:
- Exact position detection (0.0 tiles) - ✅ Pass
- Within old tolerance (0.8 tiles) - ✅ Pass  
- Improvement zone (1.8 tiles) - ✅ Pass (old: miss, new: hit)
- Beyond new tolerance (3.0 tiles) - ✅ Pass (correctly rejected)
- Diagonal detection (2.4 tiles) - ✅ Pass (old: miss, new: hit)

## Functions Affected
The change affects the primary chart tag detection function used in the right-click workflow:

- `ChartTagUtils.find_chart_tag_at_position()` - Main detection function
- Used by right-click event handler in `core/events/handlers.lua`
- Used by teleport strategy pattern in `core/pattern/teleport_strategy.lua`

## Compatibility
- **Backward Compatible:** No breaking changes to existing functionality
- **No Configuration Required:** The improvement is automatic for all users
- **No Performance Impact:** Same detection algorithm, just larger search radius

## Verification
- ✅ No syntax errors in modified files
- ✅ All detection logic remains intact  
- ✅ Test suite confirms expected behavior improvements
- ✅ Other detection systems (using player teleport radius) unaffected

---
**Fix Date:** 2025-06-17  
**Status:** ✅ Complete and Tested  
**Priority:** High (User Experience Improvement)
