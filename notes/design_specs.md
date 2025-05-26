# TeleportFavorites – Design Specs

## Overview
TeleportFavorites is a Factorio mod that allows players to mark, favorite, and teleport to locations on the map using a robust, multiplayer-safe, and surface-aware system. The mod features a modular architecture, a persistent data cache, and a modern, extensible GUI for managing favorites and map tags.

This document provides a high-level overview of the mod's goals, architecture, and main features. It is intended as a starting point for developers and maintainers.

---

## Goals
- Allow players to create, favorite, and teleport to map tags.
- Provide a robust, multiplayer-safe, and surface-aware persistent data system.
- Offer a modern, extensible GUI for managing favorites and map tags.
- Support synchronization for chart_tag, tag and player.favorites, migration, and multiplayer edge cases.
- Maintain idiomatic, modular, and testable Lua code.

---

## Main Features
- Favorite bar GUI for quick access to favorite locations.
- Tag editor GUI for creating, editing, and managing map tags, including the movement of tags
- Persistent, surface-aware storage of favorites and tags and chart_tags in `storage`.
- Multiplayer-safe tag and favorite synchronization.
- Modular codebase with clear separation of concerns.
- Comprehensive test suite and documentation.
- Cross-surface and global favorite operation will not be used. Managing favorites for a given surface (or the player's current surface) is the goal of the mod

---

## File Structure
- `core/` – Core logic, persistent cache, tag/favorite management, and context.
- `core/cache/` – Persistent data cache and helpers (all persistent data is stored in `storage`).
- `core/chart_tag/` – Class definitions and methods for managing chart_tags
- `core/tag/` – Class definitions and methods for managing tags
- `core/control/` – Lifecycle, event, and utility modules. Top-level event handlers are now split into extension modules (see `control_fave_bar.lua`, `control_tag_editor.lua`, `control_data_viewer.lua`).
- `core/pattern/` – Class definitions and methods for managing design patterns
- `core/sync_tag/` – sync taghronization and migration logic.
- `core/types/` – Annotations and definitions for external types
- `core/utils/` – Helper files
- `gui/` – GUI modules for the favorite bar, tag editor, and cache viewer. All gui modules should use base_gui.lua for shared properties and methods
- `tests/` – Automated test suite for all major modules.
- `notes/` – Design specs, data schema, and architecture documentation. This will be updated as the project progresses

---

## Sync and Multiplayer

- Only players who have created a chart_tag or tag (or where the last_user information is blank or nil) may edit a tag and associated chart_tag. If a players selects a tag and is allowed to make changes, then the associated chart_tag's last user sohuld be updated to the editing player's player.name. Chart_tag.last_user should always use the player's name and not the index or player object.
- if a player leaves the game (or is kicked out, etc):
    -- for all storage.players[player_index]surfaces[].favorites, examine their favorites and update any matching tags by removing the player's index from the faved_by_players
    -- if now, the related tag is owned by the player (chart_tag.last_user == player.name) has no faved_by_players, then delete the tag (and associated chart_tag)
    -- next, check all surfaces for any tags created by the player. for each tag, ensure the player's index in faved_by_players is removed (if present). And if the the faved_by_players is empty after this check, then delete the tag. ie: if another player has favorited the position, then do not delete. If the tag is not deleted, reset the last_user to nil or ""

---

## Error Handling
- we will decide on a case by case basis how errors will be shown, if at all, to the user.
- Have basic methods for doing storage dumps, player dumps. Should also have internal methods for presenting flying messages, outputting to the chat log and logging into files. The /factorio-current.log and a /teleport-favorites.log files should have methods for logging to their files
- The default is to print to the player's chat log

---

## Migrations
- to be determined. will be handled by mod version comparisons stored in the persistent storage. 
- us the `migrations` folder for related code.

---

## Debugging tools
- I plan to create a few debug helpers. More to come on this issue

## See Also
- `data_schema.md` – Persistent data schema and structure.
- `architecture.md` – Detailed architecture and module relationships.
- `coding_standards.md` – Coding conventions and best practices.
- `factorio_specs.md` – Notes regarding how factorio modding works
