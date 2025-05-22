# FavoriteTeleport – Architecture

## Overview
This document describes the architecture of the FavoriteTeleport mod, including its modular structure, data flow, and key design patterns. It is intended to help developers understand how the mod is organized and how its components interact.

---

## High-Level Structure
- **Persistent Data:** All persistent data is stored in `storage` and managed via the `core/cache` module.
- **Core Modules:** Handle tag/favorite logic, context, and multiplayer safety.
- **GUI Modules:** Provide user interfaces for managing favorites, tags, and settings.
- **Sync_Tag:** Ensures tag/favorite consistency across multiplayer and surfaces.
- **Lifecycle & Events:** Manage mod initialization, configuration changes, and event registration.

---

## Module Breakdown
- All modules should use a class paradigm. Use emmylua definitions to achieve this goal. Store external type in the core/types folder
- `core/cache/` – Persistent data cache, schema, init methods and helpers.
- `core/control/` – Lifecycle, event, and utility modules.
- `core/patterns/` – eg: Observer module. Files to handle design pattern logic
- `core/sync_tag/` – sync taghronization and migration logic.
- `core/types/` – for external type definitions
- `core/utils/` – will hold a variety of helper files
- `core/utils/version.lua` – a utility file to record the version information
    from the info.json file to make the version number readily available
    to the codebase. It is created and updated by update_version.py
- `core/favorite.lua` – Favorite object logic and helpers.
- `core/chart_tag.lua` – Chart tag object logic and helpers.
- `core/map_tag.lua` – Map tag object logic and helpers.
- `core/error_handling.lua` – Centralizes error handling and displying the information to the user and/or logging to the correct files
- `gui/` – GUI modules for favorite bar, tag editor, and cache viewer.
- `core/gps.lua` - used for helper file for gps conversion to a map position and vice versa. Includes any helper methods related to gps

---

## Data Flow
1. **Player Action:** Player interacts with the GUI or map.
2. **GUI/Event Handler:** Calls into core logic (e.g., add favorite, move tag). 
3. **Core Logic:** Updates persistent data in `storage` via `Cache`.
4. **sync tag:** Ensures multiplayer and surface consistency.
5. **GUI Update:** Observers update the GUI to reflect changes.

---

## Key Patterns
- **Surface Awareness:** All helpers and accessors are surface-aware.
- **Observer Pattern:** Used for GUI updates and event notification.
- **Command Pattern:** Used for event handling.
- **Builder Pattern:** Used for constructing user-interfaces. In our case, the tag editor and the favorites bar.
- **Strategy Pattern:** Used for validation and error handling
- **Modularization:** Each concern (cache, GUI, tag sync, etc.) is in its own module.
- **Testability:** All logic is testable and covered by automated tests.

---

## See Also
- `design_specs.md` – Project goals and feature overview.
- `data_schema.md` – Persistent data schema and structure.
- `coding_standards.md` – Coding conventions and best practices.
- `factorio_specs.md` – Notes regarding how factorio modding works
