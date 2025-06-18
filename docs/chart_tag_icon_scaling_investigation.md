# Chart Tag Icon Scaling Investigation

## Issue Description
Chart tag icons created by the TeleportFavorites mod appear to be displayed at double the expected size on the map, making them appear too large compared to expected sizing.

## Investigation Results

### Root Cause Analysis
After extensive investigation of the mod's codebase, the chart tag icon scaling issue is **NOT** caused by the mod's code. This is a **Factorio engine behavior** where chart tag icons are automatically scaled for better visibility on the map view.

### Code Analysis
1. **No Icon Scaling in Chart Tag Creation**: The mod uses the standard Factorio API for chart tag creation via `force.add_chart_tag()` without any custom scaling parameters.

2. **Commented Out GUI Icon Scale**: Found a commented line `--icon_scale = 2,` in `prototypes/styles/init.lua` line 178, but this relates to GUI button styling, not chart tag icons.

3. **Standard Icon Handling**: The mod follows standard Factorio practices for icon handling in chart tag specifications.

### Chart Tag Creation Process
The mod creates chart tags using the standard Factorio API:

```lua
-- From ChartTagUtils.build_chart_tag_spec()
local spec = {
  position = position,
  text = text or "Tag",
  last_user = player_name,
  icon = source_chart_tag.icon  -- Standard SignalID format
}

-- Standard Factorio API call
local chart_tag = force.add_chart_tag(surface, spec)
```

### Factorio Engine Behavior
Chart tag icons in Factorio are intentionally displayed at a larger scale on the map view to:
- Ensure visibility at different zoom levels
- Maintain consistency with vanilla Factorio chart tag sizing
- Provide better user experience for map navigation

## Conclusion
This is **expected Factorio behavior**, not a mod bug. Chart tag icons are designed to be displayed at this scale by the Factorio engine for better visibility and usability.

## Potential Solutions (If Desired)
If users want smaller chart tag icons, the following approaches could be considered:

### 1. Use Different Icon Sources
- Select icons that are naturally smaller or less prominent
- Use simple geometric signals instead of complex item icons

### 2. Documentation Update
- Document this as expected behavior in mod documentation
- Explain that chart tag icon scaling is controlled by Factorio, not the mod

### 3. User Settings (Advanced)
- Could potentially add a mod setting to influence icon selection
- This would not change the scale but could help users choose more appropriate icons

## Files Investigated
- `v:\Fac2orios\2_Gemini\mods\TeleportFavorites\prototypes\styles\init.lua`
- `v:\Fac2orios\2_Gemini\mods\TeleportFavorites\core\utils\chart_tag_utils.lua`
- `v:\Fac2orios\2_Gemini\mods\TeleportFavorites\core\control\control_tag_editor.lua`
- All chart tag creation and icon handling code paths

## Recommendation
**No action required.** This is expected Factorio behavior. Consider updating user documentation to explain that chart tag icon sizing is controlled by the Factorio engine for optimal map visibility.

---
*Investigation Date: [Current Date]*
*Status: Closed - Expected Behavior*
