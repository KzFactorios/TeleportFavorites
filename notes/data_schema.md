# FavoriteTeleport – Data Schema

## Overview
Defines the persistent data structures for the mod, including player favorites, map tags, and settings. All data is managed via the `cache` module and is surface-aware.

---

## Top-Level Schema

```lua
{
  mod_version = "0.0.01",
  tag_editor_positions = {
    [player_index] = position
  },
  players = {
    [player_index] = {
      toggle_fave_bar_buttons = boolean,
      render_mode = string,
      -- ...other per-player data
      surfaces = {
        [surface_index] = {
          favorites = {
            [slot_number] = {
              gps = string
              slot_locked = boolean,
            },
          },
          -- ...other per-surface player data
        }
      },
    },
  },
  surfaces = {
    [surface_index] = {
      map_tags = {
        [gps] = {
          faved_by_players = { [player_index] = true },
          -- ...other tag fields
        },
      },
      chart_tags = { -- used as a cache for the surface to reduce global data calls
                    -- refreshes when the cache is empty by game.forces["player"].find_chart_tags(surface)
        LuaCustomChartTag
      }
    },
  },
  -- ...other global mod data
}
```

---

## Player Favorites
- Each player has a `favorites` table for each surface.
- Each favorite is keyed by slot number and contains a `gps` string and a `slot_locked` flag.

## Map Tags
- Stored per-surface in `surfaces[surface_index].map_tags`.
- Each tag tracks which players have favorited it via `faved_by_players`.

## Settings
- Per-player settings (e.g., `toggle_fave_bar_buttons`, `render_mode`) are stored at the player level.
- Mod-wide settings (e.g., `mod_version`) are stored at the root.

---

## Notes
- All helpers and accessors must be surface-aware.
- No legacy/ambiguous fields (e.g., `qmtt`, `qmt`).
- See also: `architecture.md`, `coding_standards.md`.
