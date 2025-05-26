# TeleportFavorites – State of the Mod (2025-05-25)

## User Manual

### Overview
TeleportFavorites is a robust, multiplayer-safe Factorio mod for managing teleportation favorites and map tags. It provides a modern, accessible GUI for quick teleportation, tag editing, and data inspection, with full multiplayer and surface-awareness support.

### Main Features
- **Favorites Bar:**
  - Quick-access bar for teleporting to saved locations.
  - Drag-and-drop reordering, lock/unlock, and slot management.
  - Surface-aware and multiplayer-safe.
- **Tag Editor:**
  - Create, edit, move, and delete map tags with icon and text.
  - Move-mode for relocating tags on the map.
  - Ownership and favorite state management.
  - Confirm/cancel dialogs and error feedback.
- **Data Viewer:**
  - Inspect player, surface, and lookup data in a scrollable, tabbed GUI.
  - Adjustable font size and opacity.
  - Designed for developer and power-user workflows.
- **Robust Data Handling:**
  - All persistent data is managed via the `Cache` module.
  - Multiplayer-safe, surface-aware, and extensible.
- **Accessibility & UX:**
  - Keyboard and mouse accessible.
  - Consistent vanilla-like styling, with custom highlights for key actions.
  - Error and confirmation messages are always clear and localizable.

### How to Use
- **Favorites Bar Visibility:** The favorites bar is shown or hidden automatically based on mod settings and game state. There is no dedicated hotkey or command to open it.
- **Edit a Tag:** Right-click a favorite or use the tag editor hotkey. Edit text/icon, move or delete the tag, or toggle favorite status.
- **Move a Tag:** Enter move mode in the tag editor, then click a new location on the map.
- **View Data:** Open the data viewer with Ctrl+F12 (default hotkey) or via command. Switch tabs for player, surface, or lookup data. Adjust font/opacity as needed.

### Advanced/Developer Features
- All GUIs are modular and extensible.
- Data viewer exposes internal state for debugging and development.
- All persistent data is surface- and player-aware.
- All public APIs and helpers are EmmyLua-annotated for IDE support.

## Project Review

### Architecture
- Modular, event-driven design.
- All major GUIs and helpers are in their own files/folders.
- Top-level event handlers are now split into extension modules for maintainability.
- Persistent data schema is documented and enforced.
- 100% of persistent data access is via the `Cache` module.

### Documentation
- All public APIs, helpers, and modules are EmmyLua-annotated.
- All new/changed features are documented in `notes/`.
- Coding standards, design specs, and architecture docs are up to date.
- Linter policy: No more than 2 attempts to fix any linter issue per request; revisit persistent issues in future passes.

### Known Issues & TODOs
- Some linter false positives remain due to Factorio's dynamic API and LocalisedString handling.
- Some GUI event logic (notably drag-and-drop and certain tag editor actions) remains partially monolithic and could be further modularized into dedicated handler modules for maintainability.
- More unit and integration tests are needed for helpers and GUI logic.
- Some style/layout tweaks and accessibility improvements are still possible.
- See `notes/TODO.md` for the current actionable TODO list.

### Suggestions for Improvement
- Continue modularizing event logic and helpers.
- Expand test coverage, especially for multiplayer and edge cases.
- Add more robust error handling and user feedback for all GUIs, with a touch of fantasy and mystique. Error and confirmation messages now include flavorful, lore-inspired phrasing to enhance immersion and fun, in keeping with the Factorio v2 spirit.
- Consider lazy loading or paging for large data sets in the data viewer if needed.
- All custom button styles are now unified: every interactive button in the mod uses the `tf_slot_button` style, defined in `prototypes/styles.lua` and referenced in all GUI modules. This ensures a consistent, accessible, and vanilla-aligned look across the entire mod.
- Continue to update documentation as the project evolves.

---

*This document will be updated as the project progresses. For the latest TODOs and technical notes, see `notes/TODO.md` and `notes/coding_standards.md`.*
