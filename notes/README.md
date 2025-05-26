# TeleportFavorites – Notes Index & Organization

This document summarizes and organizes the key points from all files in the `notes/` folder as of May 23, 2025. Use this as a quick reference and onboarding guide. For full details, see the individual files.

---

## 1. **Design Specs** (`design_specs.md`)
- **Goals:**
  - Mark, favorite, and teleport to map locations.
  - Multiplayer-safe, surface-aware, robust persistent data.
  - Modern, extensible GUI for favorites/tags.
- **Features:**
  - Favorite bar GUI, tag editor GUI, persistent storage, multiplayer sync, modular codebase, comprehensive tests.
- **Data Flow:** Player → GUI/Event → Core Logic → Sync → GUI Update.
- **Sync/Multiplayer:** Tag/favorite ownership, deletion, and migration rules.
- **Error Handling:** Print to chat, log files, debug helpers.
- **Migrations:** Versioned, handled via `migrations/`.

## 2. **Architecture** (`architecture.md`)
- **Structure:** Persistent data in `storage` via `core/cache`. Core modules for logic, GUI for interface, sync for multiplayer, lifecycle/events for init.
- **Patterns:** OOP, Observer, Command, Builder, Strategy, modularization, testability.
- **File Structure:**
  - `core/` (logic, cache, tag/favorite, context)
  - `gui/` (favorite bar, tag editor, cache viewer)
  - `tests/`, `notes/`, `migrations/`

## 3. **Data Schema** (`data_schema.md`)
- **Top-Level Schema:**
  - `players[player_index].surfaces[surface_index].favorites[slot] = {gps, slot_locked}`
  - `surfaces[surface_index].tags[gps] = {faved_by_players}`
  - `_G["Lookups"].surfaces[surface_index] = {chart_tags, tag_editor_positions}`
- **GPS:** String format `xxx.yyy.s`, helpers for conversion, always surface-aware.
- **Tag/ChartTag:** Tag requires a chart_tag; chart_tag may exist without tag. Deletion/move rules.
- **Settings:** Per-player and mod-wide, versioned.

## 4. **Coding Standards** (`coding_standards.md`)
- **General:**
  - Per-line suppression comments preferred.
  - Strict EmmyLua annotation, modularity, surface-awareness, descriptive naming.
  - Requires at top, alphabetized.
- **Structure:** Organized by concern, helpers in `core/utils/`, GUI in `gui/`, tests in `tests/`. Top-level event handlers are split into extension modules (`control_fave_bar.lua`, `control_tag_editor.lua`, `control_data_viewer.lua`).
- **Persistent Data:** Only via `Cache`, primitives only, schema in `data_schema.md`.
- **Testing:** 100% coverage, edge/multiplayer cases, mirrored filenames.
- **Documentation:** Update all docs as project evolves, use EmmyLua, document all public APIs.
- **Patterns:** OOP, GoF patterns, event-driven, surface-aware, no leading underscores for private fields.

## 5. **Pattern Class Notes** (`pattern_class_notes.md`)
- **Pattern Base Classes:**
  - Builder, Command, Composite, Facade, Observer, Proxy, Singleton, Strategy, Adapter.
  - Each lists purpose, key methods, and example usage.
- **Domain Classes:**
  - Favorite, PlayerFavorites, Lookups, Tag: fields, methods, and responsibilities.

## 6. **Test Plan** (`test_plan.md`)
- **Coverage:** 100% for core logic/helpers, GUI, edge/multiplayer.
- **Structure:** Tests in `tests/`, mirrored filenames, integration for multiplayer.
- **Scenarios:** Add/remove/update favorites, tag CRUD, teleport, multiplayer sync, GUI, migration.
- **How to Run:** Use Factorio mod test runner or Busted.

## 7. **Factorio Specs** (`factorio_specs.md`)
- **Persistence:** Only primitives/tables in `storage`, never objects/functions.
- **`storage` vs `global`:** Use `storage` for Factorio 2.0+.
- **GUI Style:** Use vanilla styles, module system, responsive layouts, lifecycle functions, style inspector.
- **Summary Table:** Allowed/disallowed types, GUI best practices.

## GPS String Format and Usage

- **GPS values must always be strings** in the format `xxx.yyy.s`, where:
  - `xxx` is the X coordinate (may be negative, always padded to the configured length, including sign if negative)
  - `yyy` is the Y coordinate (may be negative, always padded to the configured length, including sign if negative)
  - `s` is the surface index (always an integer, may be negative in rare cases)
- **Valid examples:**
  - `-000123.000456.1`
  - `000123.-000456.1`
  - `-000123.-000456.1`
  - `000123.000456.1`
- **GPS must never be a table or any other type.**
- **Helpers** in `core/utils/gps_helpers.lua` are provided to convert between GPS strings and tables for internal use, but the canonical value for all storage, comparison, and API is always a string.
- **Parsing:** If a GPS string is not valid, helpers will return `nil` or a blank GPS value. Always validate GPS strings before use.
- **Legacy/Vanilla Format:** If a GPS string is encountered in the vanilla `[gps=x,y,s]` format, it will be normalized to the canonical string format on construction.

> **Note:** All code, tests, and documentation must treat GPS as a string in this format. Do not store or pass GPS as a table except for temporary parsing or conversion.

---

**Redundancy is minimized above, but some repetition is retained for clarity and onboarding.**
- For full details, see the individual files in `notes/`.
- Update this index as the project evolves.
