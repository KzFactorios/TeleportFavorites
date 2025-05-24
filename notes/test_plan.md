# TeleportFavorites – Test Plan

## Overview
This document describes the test plan for the TeleportFavorites mod, including test coverage goals, test structure, and key scenarios. All core logic, helpers, and GUI modules must be covered by automated tests.

---

## Test Coverage Goals
- 100% coverage for all core logic and helpers.
- Comprehensive tests for GUI actions and event handlers.
- Edge case and multiplayer scenario coverage.

---

## Test Structure
- All test files are located in the `tests/` directory.
- Each core module and helper has a corresponding test file (e.g., `favorite_spec.lua`, `tag_spec.lua`).
- GUI modules have dedicated test files for actions, validation, and edge cases.
- Integration tests cover end-to-end scenarios and multiplayer edge cases.

---

## Key Scenarios
- Adding, removing, and updating favorites.
- Creating, editing, and deleting map tags.
- Teleporting to favorite locations.
- Multiplayer tag/favorite synchronization.
- Surface-aware data access and mutation.
- GUI open/close, update, and validation logic.
- Migration and version upgrade scenarios.

---

## Running Tests
- Use the Factorio mod test runner or a compatible Lua test framework. The plan is to use Busted
- All tests should pass before merging changes.

---

## See Also
- `design_specs.md` – Project goals and feature overview.
- `architecture.md` – Detailed architecture and module relationships.
- `coding_standards.md` – Coding conventions and best practices.
- `data_schema.md` – Persistent data schema and structure.
- `factorio_specs.md` – Notes regarding how factorio modding works
