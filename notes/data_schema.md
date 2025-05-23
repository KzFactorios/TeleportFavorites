# FavoriteTeleport – Data Schema

## Overview
Defines the persistent data structures for the mod, including player favorites, map tags, and settings. All data is managed via the `cache` module and is surface-aware.

---

## Top-Level Schema

```lua
{
  mod_version = "0.0.01",
  players = {
    [player_index] = {
      toggle_fave_bar_buttons = boolean,
      render_mode = string,
      surfaces = {
        [surface_index] = {
          favorites = {
            [slot_number] = {
              gps = string,
              slot_locked = boolean,
            },
          },
        },
      },
    },
  },
  surfaces = {
    [surface_index] = {
      tags = {
        [gps] = { faved_by_players = { [player_index: uint] } },
      }
    },
  },
}

_G["Lookups"] = {
  surfaces = {
    [surface_index] = {
      chart_tags = { LuaCustomChartTag[] },
      tag_editor_positions = { [player_index] = gps },
    }
  }
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
