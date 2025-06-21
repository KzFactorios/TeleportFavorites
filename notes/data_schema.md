# TeleportFavorites – Data Schema

## Overview
Defines the persistent data structures for the mod, including player favorites, map tags, and settings. All data is managed via the `cache` module and is surface-aware.

---

## Top-Level Schema

### Persistent Storage (storage table)
```lua
storage = {
  mod_version = string,      -- Current mod version (e.g., "0.0.01")
  players = {
    [player_index] = {
      player_name = string,            -- Factorio player name for debugging
      render_mode = string,            -- Player's current render mode
      data_viewer_settings = {         -- Data viewer GUI preferences
        active_tab = string,           -- "player_data", "surface_data", "lookup", "all_data"
        font_size = number,            -- Font size for data viewer (6-24)
      },
      tag_editor_data = {              -- CENTRALIZED via Cache.create_tag_editor_data()
        gps = string,                  -- GPS coordinates where tag editor was opened
        move_gps = string,             -- GPS coordinates during move operations (temporary)
        locked = boolean,              -- Whether the tag is locked
        is_favorite = boolean,         -- Whether the tag is favorited (pending state)
        icon = string,                 -- Icon signal name (empty string if none)
        text = string,                 -- Tag text content (empty string if none)
        tag = Tag|nil,              -- Tag object being edited (may be nil)
        chart_tag = LuaCustomChartTag|nil, -- Associated chart tag (may be nil)
        error_message = string,        -- Error message to display (empty string if none)
        -- Additional transient fields for move mode, etc.
        move_mode = boolean|nil,       -- True if in move mode
        delete_confirmed = boolean|nil, -- True if delete confirmation is active
      },
      surfaces = {
        [surface_index] = {
          favorites = {                -- Array of Favorite objects
            [1..MAX_FAVORITE_SLOTS] = {
              gps = string,            -- GPS in format "xxx.yyy.s"
              locked = boolean,        -- Whether slot is locked against changes
            },
          },
        },
      },
    },
  },
  surfaces = {
    [surface_index] = {
      tags = {
        [gps] = {                      -- Tag objects indexed by GPS string
          gps = string,                -- Canonical GPS string "xxx.yyy.s"
          faved_by_players = {         -- Array of player indices who favorited this
            [1..n] = player_index,
          },
        },
      },
    },
  },
}
```

### Runtime Cache (_G["Lookups"])
```lua
_G["Lookups"] = {
  surfaces = {
    [surface_index] = {
      chart_tags = {                   -- Array of all chart tags on surface
        [1..n] = LuaCustomChartTag,
      },
      chart_tags_mapped_by_gps = {     -- O(1) lookup map: GPS -> chart_tag
        [gps] = LuaCustomChartTag,
      },
    },
  },
}
```

---

## Player Favorites
- Each player has a `favorites` table per surface.
- Each favorite: `{ gps: string, slot_locked: boolean }`.
- `gps` links to `surfaces[index].tags`.

## GPS
- Format: `xxx.yyy.s` (x, y: position, s: surface index; pad to 3 digits, sign for negatives).
- Helper: `convert_gps_to_position_string(gps)` → `xxx.yyy` (no surface).
- Always validate surface index; extract from object if needed.
- Use player.surface.index for all surface/gps helpers.

## Map Tags
- Stored in `surfaces[surface_index].tags`.
- Each tag must have a matching chart_tag; chart_tags may exist without tags.
- Tags and chart_tags are linked by gps/position.
- On tag move: create new chart_tag, copy info, delete old.
- chart_tags cache rebuilds from `game.forces["player"].find_chart_tags(surface_index)` if empty.

## Settings
- Per-player: at player level.
- Mod-wide: at root (only `mod_version` is persisted).
- Update version via `update_version.py` → `core/utils/version.lua`.

---

## Notes
- All helpers/accessors must be surface-aware.
- No legacy/ambiguous fields.
- See also: `architecture.md`, `coding_standards.md`.
