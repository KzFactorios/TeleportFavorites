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

## Paradigms and Patterns

- **Class-based OOP:** All core modules and helpers should use idiomatic Lua class patterns, with strict EmmyLua annotations for all classes, fields, and methods. Use `---@class`, `---@field`, `---@param`, and `---@return` for documentation and IDE support.
- **Design Patterns:** The following classic design patterns are implemented and should be used where appropriate: Adapter, Facade, Proxy, Singleton, Observer, Builder, Command, Strategy, Composite. Each pattern base class is located in `core/pattern/` or `core/patterns/` and documented in `notes/pattern_class_notes.md`.
- **Surface Awareness:** All helpers and accessors must be surface-aware and multiplayer-safe.
- **Event-driven Architecture:** Use Factorio's event system for initialization, surface management, and runtime cache handling. Register event handlers in `control.lua`.
- **Persistent vs. Runtime Data:** Persistent data must be managed via the `core/cache` module and stored in `storage`. Runtime-only (non-persistent) data must use the runtime cache (`core/cache/lookups.lua`) and never be stored in persistent storage.
- **Strict EmmyLua Annotation:** All classes, fields, and methods must be annotated for strictness and IDE support. See `core/types/factorio.emmy.lua` for Factorio runtime types and type aliases.
- **No leading underscores for private fields:** For private or internal fields in classes, do not use a leading underscore (e.g., use `chart_tag` instead of `_chart_tag`). This is the preferred convention for this codebase.

---


## See Also
- `design_specs.md` – Project goals and feature overview.
- `architecture.md` – Detailed architecture and module relationships.
- `data_schema.md` – Persistent data schema and structure.
- `factorio_specs.md` – Notes regarding how factorio modding works
