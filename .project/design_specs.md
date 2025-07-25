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

## Design Patterns and Architecture

```
┌────────────────────────────────────────────────────────────┐
│                 TeleportFavorites Architecture             │
├────────────────┬──────────────────┬─────────────────────┬──┤
│   GUI Layer    │  Event Handlers  │  Business Logic     │  │
│                │                  │                     │  │
│ - Tag Editor   │ - Input Events   │ - Tag Management    │  │
│ - Favorites Bar│ - Button Clicks  │ - Favorite Logic    │  │
│ - NA           │ - Mouse Events   │ - Teleport Strategy │  │
├────────────────┴──────────────────┴─────────────────────┤  │
│              Cache / Storage (Source of Truth)          │  │
├──────────────────────────────────────────────────────┬──┤  │
│               Surface-Aware Data:                    │  │  │
│ - Player Favorites                                   │  │  │
│ - Chart Tags                                         │  │  │
│ - Tag Editor Data                                    │  │  │
│ - Player Settings                                    │  │  │
└──────────────────────────────────────────────────────┴──┴──┘
```

### Storage as Source of Truth Pattern

The mod implements a strict "storage as source of truth" pattern for all GUI state management:

**Core Principle:** Persistent storage (`tag_editor_data`, `player_favorites`, etc.) is the authoritative source for all state. GUI elements are never read from - they only display stored values and immediately save changes back to storage.

**Implementation:**
- **Input Events** → **Immediate Storage Save** → **UI Refresh from Storage**
- **Business Logic** → **Read from Storage Only** → **Never from GUI Elements**
- **State Changes** → **Update Storage** → **Rebuild UI from Storage**

**Benefits:**
- Eliminates synchronization bugs between GUI and data
- Prevents nil reference errors from missing GUI elements  
- Provides immediate data persistence and recovery
- Simplifies multiplayer state management
- Enables reliable undo/redo functionality

This pattern is implemented consistently across all complex GUIs

### Modular Event Handling

All GUI events are routed through a centralized dispatcher (`gui_event_dispatcher.lua`) that:
- Provides robust error handling and logging
- Routes events to appropriate domain handlers
- Implements the `{gui_context}_{purpose}_{type}` naming convention
- Supports immediate storage persistence on input changes

### Surface-Aware Data Management

All data operations are surface-aware through the `Cache` module:
- Player favorites are stored per-surface
- Tag data is organized by surface index  
- All helpers accept surface/player context
- Cross-surface operations are explicitly not supported

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
- `core/control/` – Lifecycle, event, and utility modules. Top-level event handlers are now split into extension modules (see `control_fave_bar.lua`, `control_tag_editor.lua`).
- `core/pattern/` – Class definitions and methods for managing design patterns
- `core/sync_tag/` – sync taghronization and migration logic.
- `core/types/` – Annotations and definitions for external types
- `core/utils/` – Helper files
- `gui/` – GUI modules for the favorite bar, tag editor. All gui modules should use base_gui.lua for shared properties and methods
- `tests/` – Automated test suite for all major modules.
- `.project/` – Design specs, data schema, and architecture documentation. This will be updated as the project progresses

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

---

## GUI Documentation and Best Practices (2025-06-10)

All GUI modules use shared builder functions from `gui_base.lua` for consistent style and maintainability.

**GuiBase Builder Functions:**
```
GuiBase
├── create_frame(parent, name, direction, style)
├── create_button(parent, name, caption, style)
├── create_label(parent, name, caption, style)
├── create_sprite_button(parent, name, sprite, tooltip, style, enabled)
├── create_element(element_type, parent, opts)
├── create_hflow(parent, name, style)
├── create_vflow(parent, name, style)
├── create_flow(parent, name, direction, style)
├── create_draggable(parent, name)
├── create_titlebar(parent, name, close_button_name)
└── create_textbox(parent, name, text, style, icon_selector)
```
All builder functions use defensive checks and default styles for robust GUI creation. See `gui_base.lua` for details.

The `{gui_context}_{purpose}_{type}` naming convention is enforced and documented for all GUIs.
Event filtering and builder/command pattern usage are described in each GUI's notes file.
Best practices for accessibility, error handling, and multiplayer safety are documented and implemented.
See `tag_editor.md`, `fave_bar.md` for details.

## See Also
- `data_schema.md` – Persistent data schema and structure.
- `architecture.md` – Detailed architecture and module relationships.
- `coding_standards.md` – Coding conventions and best practices.
- `factorio_specs.md` – Notes regarding how factorio modding works
