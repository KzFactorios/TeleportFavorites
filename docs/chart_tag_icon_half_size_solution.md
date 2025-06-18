# Chart Tag Icon Half-Size Solution

## Problem Statement
Chart tag icons appear twice the expected size on the map when created through the mod. Users have requested the ability to present icons at half size to reduce visual impact while maintaining chart tag functionality.

## Root Cause Analysis
- Chart tag icon scaling is controlled by the Factorio engine, not the mod
- The engine intentionally scales chart tag icons for map visibility
- Standard chart tags accept SignalID references like `{type = "virtual-signal", name = "signal-star"}`
- No direct API exists to control chart tag icon scaling

## Proposed Solution: Custom Half-Size Sprites

Create scaled-down versions of commonly used chart tag icons as custom sprites, following the existing pattern used by `tf_star_disabled` sprite.

### Implementation Approach

1. **Create Half-Size Virtual Signal Sprites**
   - Define custom sprites for popular virtual signals (star, heart, checkmark, etc.)
   - Use `scale = 0.5` parameter to create visually smaller icons
   - Name them with `_half` suffix for clarity

2. **Implement Icon Selection Helper**
   - Create utility function to map standard signals to half-size variants
   - Provide fallback to original icons if half-size version doesn't exist
   - Allow user preference for using half-size vs. full-size icons

3. **Modify Chart Tag Creation Process**
   - Update `ChartTagUtils.build_chart_tag_spec()` to optionally convert icons
   - Add user setting to enable/disable half-size icon mode
   - Maintain backward compatibility with existing tags

### Benefits
- Reduces visual clutter on the map
- Maintains full chart tag functionality
- User-configurable preference
- Backward compatible with existing tags
- Follows established mod patterns

### Technical Implementation
- Extend `data.lua` with half-size sprite definitions
- Add icon conversion utility in `ChartTagUtils`
- Provide mod setting for user preference
- Update tag editor to preview half-size icons

## File Changes Required

1. `data.lua` - Add half-size sprite definitions
2. `core/utils/chart_tag_utils.lua` - Add icon conversion logic
3. `settings.lua` - Add user preference setting
4. `gui/tag_editor/tag_editor.lua` - Update icon preview
5. Documentation updates

## Alternative Approaches Considered

### Direct Sprite Replacement
- Replace original virtual signal sprites entirely
- **Rejected**: Would affect other mods and base game

### Chart Tag Post-Processing
- Modify chart tags after creation
- **Rejected**: No API exists to modify chart tag icon scale

### Custom Chart Tag Implementation
- Create entirely custom chart tag system
- **Rejected**: Too complex, loses integration with base game features

## Conclusion

The custom half-size sprite approach provides the best balance of functionality, compatibility, and user experience while working within Factorio's API limitations.
