# FavoriteTeleport – Coding Standards

## Overview
This document defines the coding standards and best practices for the FavoriteTeleport mod. All contributors should follow these guidelines to ensure code quality, maintainability, and consistency.

---

## General Guidelines
- Use idiomatic Lua and Factorio modding conventions.
- Prefer modular, single-responsibility modules.
- All persistent data must be managed via the `core/cache` module and be stored in `storage`. Do not namespace the data in storage
- All helpers and accessors must be surface-aware.
- Avoid legacy/ambiguous fields and naming (e.g., `storage`, `qmtt`, `qmt`).
- Use descriptive variable and function names.
- Write clear, concise comments and documentation.
- Suggest gang of four design patterns whenever applicable

---

## File and Module Structure
- Organize code by concern: core logic, cache, GUI, sync tag, tests, etc.
- Place all persistent data helpers in `core/utils/`.
- Place all GUI logic in `gui/` and submodules.
- Place all test files in `tests/`.

---

## Persistent Data
- Store all persistent data in `storage`.
- Never use `_G` or any other global for persistence.
- Use the `Cache` module for all persistent data access and mutation.

---

## Surface Awareness
- All helpers and accessors must take surface context into account.
- Never assume a single surface or player.

---

## Testing
- All core logic and helpers must be covered by automated tests.
- Use the `tests/` directory for all test files.

---

## Documentation
- Update design specs, architecture, and data schema as the project evolves.
- Document all public functions and modules.

---

## See Also
- `design_specs.md` – Project goals and feature overview.
- `architecture.md` – Detailed architecture and module relationships.
- `data_schema.md` – Persistent data schema and structure.
