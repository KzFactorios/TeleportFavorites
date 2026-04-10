title: "TeleportFavorites Data Schema"
description: "Core logic and data rules"
applyTo: "core/cache/**/*.lua, **/*.lua"


# TeleportFavorites: Data Schema & Storage Rules

## 1. CRITICAL: MULTIPLAYER SAFETY
- **NO USERDATA IN STORAGE**: Never store `LuaCustomChartTag`, `LuaPlayer`, or `LuaSurface` in `storage`.
- **Retrieval**: Store the **GPS String**, then use `Cache.Lookups.get_chart_tag_by_gps(gps)` at runtime.

## 1.1 STORAGE SCHEMA VERSION
- **`storage._tf_schema_version`**: Monotonic integer for **data-shape** migrations (not the mod semver string). Increment logic lives in [`core/cache/storage_migrations.lua`](core/cache/storage_migrations.lua); applied from `Cache.init()` on load.
- **`storage.mod_version`**: Informational string from `script.active_mods` (optional future use).

## 1.5 GPS STRING FORMAT (Canonical)

- **Canonical format**: TeleportFavorites uses a canonical GPS string for all persistent storage and lookups: `xxx.yyy.s` where:
  - `xxx` = X coordinate (integer, zero-padded to `Constants.settings.GPS_PAD_NUMBER` digits for the magnitude)
  - `yyy` = Y coordinate (integer, zero-padded to `Constants.settings.GPS_PAD_NUMBER` digits for the magnitude)
  - `s` = Surface index (integer, not padded)

- **Padding & sign rules**: Magnitudes are padded to the configured pad length; negative values include a leading minus sign followed by the padded magnitude. Example behavior is implemented in `core/utils/basic_helpers.lua` (`basic_helpers.pad`) and used by `core/utils/gps_utils.lua`.

- **Examples** (pad length = 3):
  - `099.100.1` (x=99, y=100, s=1)
  - `-005.010.1` (x=-5 -> `-005`, y=10 -> `010`, s=1)
  - `2048.-6000.1` (x=2048, y=-6000, s=1 — magnitudes exceed pad length, so full digits are used)

- **Blank GPS**: Use `Constants.settings.BLANK_GPS` to represent an empty/unset GPS value in storage.

- **Conversion & Helpers**: Always use `core/utils/gps_utils.lua` helpers to convert between map positions, tables, Factorio `[gps=x,y,s]` rich-text, and the canonical string. Do not store or pass tables or `[gps=...]` strings as persistent `gps` values — convert immediately.

- **Why**: This canonical format ensures deterministic keys for storage, indexing, and lookups across surfaces and players.

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
      -- faved_by_players: map keyed by player index (value is typically same index or true). Do not use # on this table.
      tags = { [gps] = { gps = string, faved_by_players = { [player_index] = player_index } } }
    }
  }
}