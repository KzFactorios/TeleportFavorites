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
          tag_editor_position = gps,
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
      tags = {
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
- The gps tag should be used to find the matching tag in surfaces[index].tags

## GPS
- gps is a string that ALWAYS returns in the format xxx.yyy.s, where x is the position.x coordinate, yyy is the position.y coordinbate and s is the surface index. If a coordinate is negative, the gps will reflect the negative value eg: -xxx.yyy.s or xxx.-yyy.s or -xxx.-yyy.s depending on the position to reflect
- gps is the linking field between tag.gps and a Helpers.gps_convert_from_map_position(chart_tag.position). The gps for a chart_tag will return a string formulated by position.x, position.y, surface_index as a string. both the x and y values should 
be padded to 3 places as a minimum, using 0 as the filler, and should show a minus sign if the component position value is negative. Signs are not necessary for positive values. If a coordinate is > 999 or less than -999, use that number. This means a gps coordinate could be similar to xxxxxx.-yyy.s or -xxx.yyyy.s. We are only trying to get some consistency for low numbers. The important point is that a gps string represents the x,y coordinates of a tag along with the surface index and all these values are separated with a "."
- gps is the main linking field for tag.gps = player.favorite.gps
- there should be a helper method to retrieve only the position portion of the gps without the surface_index as a string. call the method "convert_gps_to_position_string". The format for this string should be "xxx.-yyy" etc
- for gps, the surface index should always be a number, but the formatters should check that this is the case and if a surface object has been passed accidentally, the index should be extracted a s a number and applied to the gps. 
- check for valid surface indices on creation and updates
- There should be helper methods to convert a gps to a position and vice versa
- All surface and gps methods should use the player object and specifically player.surface.index to construct

## Map Tags
- essentailly a wrapper for any chart_tag in the game. If a chart_tag exists without a matching tag, that is allowed but should be updated to match a new tag whenever it is edited. 
- Stored per-surface in `surfaces[surface_index].tags`.
- Each tag MUST have a related chart_tag registered in the game.
- tags are related to chart_tags by comparing the tag.gps to the chart_tag.position (converted to a gps value)
- Upon tag creation, a matching chart_tag should be created. It is a requirement of a tag that it must have a matching chart_tag
- Each tag manages which players have favorited it via `faved_by_players`, by inserting/deleting the player's index
- If a tag is being moved to a new position, and because the position of a chart_tag is immutable, the newly selected position should be the basis for a new chart_tag. The new chart_tag should copy the information from the original chart_tag. After the new chart_tag is created, the old one can be deleted upon successful creation of a new chart_tag
- Try to avoid using chart_tags directly, as a rule they should be accessed via a tag. Exceptions to this rule will be unavoidable so do create methods to manage chart_tags
- chart_tags do not require a matching tag, but tags DO require a matching chart_tag. chart_tags that will be automatically removed by the tag delete or move processes should never be orphaned, if they no longer match their matching tag's position for some reason, this would show an error. It may require "creata a new chart_tag based on the new position and other chart_tag info then delete the original chart_tag". Log any orphans, but in general the robustness of the code should ensure the chart_tag->tag and tag->chart_tag relation. 
- storage.surfaces[surface_index].chart_tags should be treated as an in game cache only that rebuilds itself whenever storage.surfaces[surface_index].chart_tags is empty. It will rebuild itself by calling game.forces["player"].find_chart_tags(surface_index)
- if, in the rare case that a tag no longer has a matching chart_tag, then a new chart_tag should be created with matching gps -> position. The gps should also be used as the source of the surface index for the chart_tag.surface. Note that the chart_tag.surface may not be allowed to be a number, so some conversion will be required.

## Settings
- Per-player settings (e.g., `toggle_fave_bar_buttons`, `render_mode`) are stored at the player level.
- Mod-wide settings (e.g., `mod_version`) are stored at the root.
- the only truly persisted setting should be the mod's version number and it is immutable by the game. the only way to update the version number is to update the info.json file's version number using the update_version.py script. This write the version number to core/utils.version.lua and can be accessed by requiring "core/utils.version" in the necessary file:
```
local mod_version = require("core.utils.version")

local valueOfVersion = mod_version

```

---

## Notes
- All helpers and accessors must be surface-aware.
- No legacy/ambiguous fields (e.g., `qmtt`, `qmt`).
- See also: `architecture.md`, `coding_standards.md`.
