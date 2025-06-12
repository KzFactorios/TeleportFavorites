# Map Targeting Reticle Feature

## Overview

The map targeting reticle is a visual aid that appears when right-clicking in the map view. It shows collision indicators (circle and square) representing the search radius for teleportation. This feature helps players understand exactly where they will teleport to and visualizes the collision detection radius.

## Implementation Details

### Separation from Developer Mode

The map targeting reticle has been separated from developer mode functionality:
- The reticle visualization is available to all players in regular play mode
- The Positionator GUI (position adjustment tool) remains a developer-only feature
- This separation allows all players to benefit from the visual feedback when placing teleport points

### Per-Player Setting

A new per-player setting has been added to control the reticle visibility:
- Setting name: `map-reticle-on`
- Default value: `true` (enabled)
- Players can toggle this setting in the mod settings menu
- The setting applies immediately - no game restart required

### Visual Optimizations

The reticle includes several performance optimizations:
1. **Zoom-Based Rendering**:
   - When zoomed out, simplified visualization (only circle, no square or center marker)
   - Transparency adjusts based on zoom level for better visibility
   - Line width scales with zoom level

2. **Update Throttling**:
   - Update frequency adjusts based on zoom level
   - More frequent updates when zoomed in for precision
   - Less frequent updates when zoomed out to save UPS

3. **Conditional Rendering**:
   - Only renders when position changes significantly
   - Only updates when zoom level changes by more than 10%
   - Skips rendering if right mouse button is no longer held

## User Experience

Players will now see:
1. A green circle showing the teleport search radius
2. A blue square showing the bounding box dimensions
3. A red dot at the center position (when zoomed in)

These visual indicators update in real-time as the player moves the cursor while holding right-click in the map view.

## Settings Configuration

```lua
-- In prototypes/settings.lua
{
  type = "bool-setting",
  name = "map-reticle-on",
  setting_type = "runtime-per-user",
  default_value = true,
  order = "sd",
  localised_name = {"setting-name.map-reticle-on"},
  localised_description = {"setting-description.map-reticle-on"}
}
```

## Code Structure

The reticle functionality is implemented in `core/utils/positionator.lua` but has been separated from the developer-specific functionality. It now respects the `map_reticle_on` player setting for enabling/disabling the visualization.
