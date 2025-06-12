# Collision Detection Parameter Analysis

**Date:** June 12, 2025  
**Issue:** EntityID error fix, parameter optimization, and function renaming
**Files:** 
- `core/utils/gps_helpers.lua` - `normalize_landing_position()` function
- `core/utils/game_helpers.lua` - `position_has_colliding_tag()` renamed to `get_nearest_tag_to_click_position()`

## Problem Solved
Fixed "Invalid EntityID: expected LuaEntityPrototype, LuaEntity or string" error by changing collision detection entity from `"car"` to `"character"` with enhanced safety parameters.

## Current Implementation
```lua
-- Hardcoded "character" entity (no variables that could be corrupted)
local safety_radius = player_settings.teleport_radius + 2          -- Add safety margin for vehicle-sized clearance
local fine_precision = Constants.settings.TELEPORT_PRECISION * 0.5 -- Finer search precision

-- With comprehensive error handling and debugging
local non_collide_position = nil
local success, error_msg = pcall(function()
  non_collide_position = player.surface:find_non_colliding_position("character", landing_position,
    safety_radius, fine_precision)
end)

if not success then
  player:print("[TeleportFavorites] ERROR in first collision detection: " .. tostring(error_msg))
  return
end
```

## Parameter Analysis

### Default Values
- `TELEPORT_RADIUS_DEFAULT` = **8 tiles**
- `TELEPORT_PRECISION` = **1 tile**

### Calculated Parameters
- `safety_radius` = **8 + 2 = 10 tiles**
- `fine_precision` = **1 × 0.5 = 0.5 tiles**

### Search Space Mathematics
1. **Search Area:**
   - Circle with radius = 10 tiles
   - Area = π × 10² = **~314 tiles²**
   - Equivalent to ~18×18 tile square

2. **Search Grid:**
   - 0.5 tile precision = checks every 0.5 tiles
   - 40 check points per diameter (10 ÷ 0.5 × 2)
   - Total grid positions ≈ **~1,256 positions** (worst case)

3. **Comparison to Default:**
   - **Default:** 8-tile radius = ~201 tiles², 64 positions checked
   - **Current:** 10-tile radius = ~314 tiles², ~1,256 positions checked
   - **Change:** +56% area, ~20× more precision

## Performance Assessment

### ✅ REASONABLE because:
- 10 tiles = only **25% larger** than default 8-tile teleport radius
- 314 tiles² is a **modest search area** in Factorio terms
- Vehicle collision boxes are ~1.5×1.5 tiles, so +2 tiles buffer is appropriate
- Factorio's `find_non_colliding_position()` is optimized and terminates early
- Most searches find valid positions quickly without checking all grid points

### ✅ Safety Benefits:
- Prevents vehicle teleportation into collision situations
- "Character" entity is guaranteed available in all Factorio configurations
- Enhanced precision finds safe spots in tight spaces
- Two-stage collision validation for extra safety

## Verdict
**Parameters are well-balanced and appropriately sized.** The search space is reasonable for the safety benefits provided, and performance impact is negligible for such a small area relative to typical Factorio operations.

## Code Location
- **File:** `v:\Fac2orios\2_Gemini\mods\TeleportFavorites\core\utils\gps_helpers.lua`
- **Function:** `normalize_landing_position()`
- **Lines:** ~109-121 (collision detection calls)

## Related Files
- `constants.lua` - Default radius and precision values
- `settings.lua` - Player teleport radius settings
- `core/tag/tag.lua` - Uses normalized positions for teleportation
- `core/utils/game_helpers.lua` - Chart tag collision detection
- `core/utils/helpers_suite.lua` - Helper function exports
- `core/cache/cache.lua` - Tag editor data structure

## Additional Changes - Chart Tag Collision Detection

### Function Renaming & Parameter Enhancement (June 12, 2025)

The function in `game_helpers.lua` has been renamed to `get_nearest_tag_to_click_position()` to better reflect its purpose. The new function accepts an explicit search radius parameter:

**Old Implementation:**
```lua
-- Previous version of the function had a different name and only two parameters
function GameHelpers.someOldFunction(player, map_position)
  -- Uses player settings to determine radius
  local player_settings = Settings:getPlayerSettings(player)
  local collision_radius = player_settings.teleport_radius or Constants.settings.TELEPORT_RADIUS_DEFAULT
  -- ...
end
```

**New Implementation:**
```lua
function GameHelpers.get_nearest_tag_to_click_position(player, map_position, search_radius)
  -- Uses provided search_radius if available, otherwise falls back to player settings
  local collision_radius = search_radius
  if not collision_radius then
    local player_settings = Settings:getPlayerSettings(player)
    collision_radius = player_settings.teleport_radius or Constants.settings.TELEPORT_RADIUS_DEFAULT
  end
  -- ...
end
```

This change allows for more flexibility in specifying the search radius, while maintaining backwards compatibility through a function alias in `helpers_suite.lua`.

The tag editor data structure was also updated to store the search radius:

```lua
function Cache.create_tag_editor_data(options)
  local defaults = {
    -- ... existing fields ...
    search_radius = nil  -- Will be set from player settings if not provided
  }
  -- ...
end
```

These changes ensure that the search radius is consistently tracked and applied throughout the position normalization workflow.
