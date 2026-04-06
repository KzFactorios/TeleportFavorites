title: "TeleportFavorites Data Schema"
description: "Core logic and data rules"
applyTo: "core/cache/**/*.lua, **/*.lua"


# TeleportFavorites: Data Schema & Storage Rules

## 1. CRITICAL: MULTIPLAYER SAFETY
- **NO USERDATA IN STORAGE**: Never store `LuaCustomChartTag`, `LuaPlayer`, or `LuaSurface` in `storage`.
- **Retrieval**: Store the **GPS String**, then use `Cache.Lookups.get_chart_tag_by_gps(gps)` at runtime.

## 2. GPS FORMAT & LOGIC (Old Section 4)
- **Canonical Format**: `"xxx.yyy.s"` (x, y coordinates + surface index).
- **Padding**: Coordinates are padded/signed (e.g., `-005.120.1`).
- **Helpers**: 
  - `convert_gps_to_position_string(gps)` -> returns `"xxx.yyy"` (strips surface).
  - Always use `player.surface.index` to generate or validate the `.s` suffix.

## 3. DATA RELATIONSHIPS (Old Section 3)
- **Favorites**: Linked to `surfaces[index].tags` via the GPS string.
- **Tag Ownership**: Managed in `surfaces[surface_idx].tags[gps].faved_by_players`.
- **Move Logic**: On tag move: 
  1. Create new `chart_tag`. 
  2. Copy metadata. 
  3. Update `storage` GPS keys. 
  4. Delete old `chart_tag`.
- **Sync**: `chart_tags` lookup must be rebuilt via `find_chart_tags(surface)` if a desync is detected.

## 4. STORAGE STRUCTURE
```lua
storage = {
  players = {
    [idx] = {
      tag_editor_data = { gps = string, text = string },
      surfaces = {
        [s_idx] = {
          favorites = { [slot] = { gps = string, locked = boolean } }
        }
      }
    }
  },
  surfaces = {
    [s_idx] = {
      tags = { [gps] = { gps = string, faved_by_players = { [1..n] = player_index } } }
    }
  }
}