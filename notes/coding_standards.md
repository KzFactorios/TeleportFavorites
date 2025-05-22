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
- Suggest gang of four design patterns whenever applicable and document when they are in use at the top of the file or at the top of a method - where is most appropriate. --- Pattern [pattern name] is acceptable
- Always put require statements at the top of the file. Do not use require statements in method calls. Always use absolute paths from the root
- It is acceptable to have helper methods within a module if they are only used locally,  when a helper method needs to be shared, it should be included in a helper file, appropriately named, in the utils/helper folder

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
- use primitive values for persisted storage values, create helper methods to convert the values back to objects when necessary.
- Do not store objects in persistent storage! It won't work

---

## Surface Awareness
- All helpers and accessors must take surface context into account.
- Never assume a single surface or player.

---

## Testing
- All core logic and helpers must be covered by automated tests.
- Use the `tests/` directory for all test files.
- Edge cases should be examined in all tests where applicable
- File names in tests/ should mirror the modules they represent

---

## Documentation
- Update design specs, architecture, and data schema, etc as the project evolves. This should be done every 5-10 iterations
- If a new style methodology, protocol or system, etc relating to the intracies of factorio version 2 modding come to light in the coding process, add the note after verifying the point into the factorio_specs.md file
- Document all public functions and modules.
- Use emmylua for formatting. 

---


## See Also
- `design_specs.md` – Project goals and feature overview.
- `architecture.md` – Detailed architecture and module relationships.
- `data_schema.md` – Persistent data schema and structure.
- `factorio_specs.md` – Notes regarding how factorio modding works
