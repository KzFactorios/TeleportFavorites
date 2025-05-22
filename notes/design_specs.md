# FavoriteTeleport – Design Specs

## Overview
FavoriteTeleport is a Factorio mod that allows players to mark, favorite, and teleport to locations on the map using a robust, multiplayer-safe, and surface-aware system. The mod features a modular architecture, a persistent data cache, and a modern, extensible GUI for managing favorites and map tags.

This document provides a high-level overview of the mod's goals, architecture, and main features. It is intended as a starting point for developers and maintainers.

---

## Goals
- Allow players to create, favorite, and teleport to map tags.
- Provide a robust, multiplayer-safe, and surface-aware persistent data system.
- Offer a modern, extensible GUI for managing favorites and map tags.
- Support synchronization for chart_tag, map_tag and player.favorites, migration, and multiplayer edge cases.
- Maintain idiomatic, modular, and testable Lua code.

---

## Main Features
- Favorite bar GUI for quick access to favorite locations.
- Tag editor GUI for creating, editing, and managing map tags, including the movement of tags
- Persistent, surface-aware storage of favorites and map_tags and chart_tags in `storage`.
- Multiplayer-safe tag and favorite synchronization.
- Modular codebase with clear separation of concerns.
- Comprehensive test suite and documentation.

---

## File Structure
- `core/` – Core logic, persistent cache, tag/favorite management, and context.
- `core/cache/` – Persistent data cache and helpers (all persistent data is stored in `storage`).
- `core/control/` – Lifecycle, event, and utility modules.
- `core/sync_tag/` – sync taghronization and migration logic.
- `gui/` – GUI modules for the favorite bar, tag editor, and cache viewer.
- `tests/` – Automated test suite for all major modules.
- `notes/` – Design specs, data schema, and architecture documentation. This will be updated as the project progresses

---

## See Also
- `data_schema.md` – Persistent data schema and structure.
- `architecture.md` – Detailed architecture and module relationships.
- `coding_standards.md` – Coding conventions and best practices.
