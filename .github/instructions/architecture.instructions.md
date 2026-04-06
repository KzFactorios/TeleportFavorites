---
name: "TeleportFavorites Architecture"
description: "System design, GUI patterns, and data flow"
applyTo: "core/**/*.lua, gui/**/*.lua"
---


# TeleportFavorites: Architecture & Patterns

## 1. GUI BUILDER PATTERN (GuiBase)
NEVER use raw `player.gui.screen.add`. Always use `GuiBase` helpers from `gui/gui_base.lua`:
- **Frames/Flows**: `create_frame`, `create_hflow`, `create_vflow`, `create_draggable`.
- **Elements**: `create_button`, `create_sprite_button`, `create_label`, `create_textbox`.
- **Special**: `create_titlebar` (includes close button logic).
- **Rule**: All `require` statements must be at the absolute top of the file.

## 2. MODULE SYSTEM
- **Logic**: Class-based paradigm with EmmyLua.
- **Cache**: `core/cache/` handles all `storage` interaction.
- **Tags**: `Tag.update_gps_and_surface_mapping` is the ONLY way to move tags/GPS data.
- **Events**: Handled via `core/events/` and extension modules (e.g., `control_fave_bar.lua`).

## 3. DATA FLOW
**Pattern**: Player Action → Event Handler → `Cache` (Storage) → Sync → GUI Update (Observer).
- **Sync**: Ensures multiplayer consistency across surfaces.
- **History**: Toggle via `Ctrl + Shift + T`. Non-blocking (no `player.opened`).

## 4. CRITICAL PATTERNS
- **Create-Then-Validate**: Since Factorio API can't pre-validate all tag constraints, use:
  1. `position_can_be_tagged()` check.
  2. `force.add_chart_tag()`.
  3. Immediate `destroy()` if final validation fails.
- **Surface Awareness**: Every helper MUST account for surface identity (Nauvis vs. Planets/Platforms).
- **Storage-First**: GUI must always reflect `storage` state, never hold its own unique state.

## 5. DIRECTORY MAP
- `core/favorite/`: Object logic & rehydration.
- `core/utils/`: `gps_utils` (GPS ↔ Position), `error_handler`.
- `gui/`: Favorites bar, Tag editor, History modal.