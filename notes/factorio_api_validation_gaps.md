# Factorio API Validation Gaps

## Overview
This document tracks situations where our validation logic may not perfectly match Factorio's internal validation, requiring the create-then-validate pattern.

## Chart Tag Validation

### Known Validation Gaps

**Our `position_can_be_tagged()` covers:**
- ✅ Player/force/surface existence
- ✅ Chunk charted status (`player.force.is_chunk_charted()`)
- ✅ Water tile detection (`Helpers.is_water_tile()`)
- ✅ Space tile detection (`Helpers.is_space_tile()`)

**Potential Factorio API restrictions we DON'T validate:**
- ❓ Surface-specific restrictions (different rules per surface type?)
- ❓ Force-specific permissions or restrictions
- ❓ Map generation state dependencies
- ❓ Mod compatibility restrictions (other mods affecting chart tag placement)
- ❓ Entity collision detection (buildings, resources, etc.)
- ❓ Distance limitations from player/spawn
- ❓ Maximum chart tags per area/surface
- ❓ Special terrain types beyond water/space

### Evidence of API Gaps

**Location:** `gps_helpers.lua:202-208`
```lua
local temp_chart_tag = player.force:add_chart_tag(player.surface, chart_tag_spec)
if not position_can_be_tagged(player, temp_chart_tag and temp_chart_tag.position or nil) then
  temp_chart_tag.destroy()
  temp_chart_tag = nil
end
```

**Reasoning:** If our validation was complete, this create-then-validate pattern wouldn't be necessary.

## Other Potential API Gaps

### Entity Placement
- Similar patterns may be needed for entity placement validation
- `LuaSurface.can_place_entity()` may not cover all edge cases

### Teleportation
- `LuaSurface.request_to_generate_chunks()` behavior may vary
- Safe teleport position detection may require actual teleport attempts

## Monitoring Strategy

1. **Log validation mismatches** when create-then-validate fails
2. **Track Factorio version changes** that affect validation behavior
3. **Monitor user reports** of unexpected validation failures
4. **Test on different surface types** (Nauvis, space platforms, modded surfaces)

## Future Improvements

- **Comprehensive testing suite** for all surface/scenario combinations
- **Version-specific validation** if Factorio API changes
- **Caching of validation results** for performance optimization
- **Enhanced error reporting** to identify new validation edge cases

## Action Items

- [ ] Add logging to create-then-validate failures to identify gaps
- [ ] Test validation on different Factorio surface types
- [ ] Monitor Factorio API documentation for validation method additions
- [ ] Create test scenarios for edge cases (water boundaries, chunk edges, etc.)
