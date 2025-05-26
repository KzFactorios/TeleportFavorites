# TeleportFavorites – Coding Standards

## Overview
This document defines the coding standards and best practices for the TeleportFavorites mod. All contributors should follow these guidelines to ensure code quality, maintainability, and consistency.

---

## General Guidelines
- I have a condition called essential tremor which attributes to my attrocious typing skills. Do your best to follow along with my instructions. If there is any ambiguity then be sure to ask! And thank you for your patience!
- Prefer per-line suppression comments (e.g., `---@diagnostic disable-next-line: ...`) over per-file suppressions. Prefer per-file suppressions over global suppressions. This ensures that static analysis is as precise and non-intrusive as possible, and that code remains readable and maintainable for all contributors.
- Use idiomatic Lua and Factorio modding conventions, including strict EmmyLua annotations for all classes, fields, and methods. All public and private fields, as well as all function parameters and return values, must be annotated for IDE support and static analysis.
- Prefer modular, single-responsibility modules. Each file should encapsulate a single concern or domain concept. Avoid monolithic files and always refactor when a file grows too large or complex.
- All persistent data must be managed via the `core/cache` module and be stored in `storage`. Do not namespace the data in storage. All persistent data access and mutation must go through the `Cache` module, which provides a strict, surface-aware, and multiplayer-safe interface.
- All helpers and accessors must be surface-aware. Never assume a single surface or player. All data access and mutation must take surface context into account, and all helper methods must accept surface or player context as parameters where appropriate.
- Avoid legacy/ambiguous fields and naming (e.g., `storage`, `qmtt`, `qmt`). Use descriptive, unambiguous names for all variables, functions, and modules.
- Use descriptive variable and function names. Avoid abbreviations unless they are widely understood in the Factorio modding community.
- Write clear, concise comments and documentation. All public functions and modules must be documented with EmmyLua annotations and descriptive comments. Private helpers should be documented where their behavior is non-obvious.
- When addressing linter issues, do not make more than 2 attempts to fix any linter issues in a single request. Further linter problems should be addressed in separate requests or future passes.
- Suggest gang of four design patterns whenever applicable and document when they are in use at the top of the file or at the top of a method - where is most appropriate. --- Pattern [pattern name] is acceptable. All pattern base classes are located in `core/pattern/` or `core/patterns/` and are documented in `notes/pattern_class_notes.md`.
- chatGPT said "Tip: You can also use local requires inside functions to break cycles:" this tip maybe true for lua (i have no idea), but it is not for factorio, ABSOLUTELY ALWAYS PUT THE REQUIRES AT THE TOP OF THE FILE!!!!!! Always put require statements at the top of the file. Do not use require statements in method calls. Always use absolute paths from the root. Always order require statements alphabetically upon save or refomatting. This ensures consistency and makes it easy to audit dependencies.
- It is acceptable to have helper methods within a module if they are only used locally. When a helper method needs to be shared, it should be included in a helper file, appropriately named, in the `core/utils/helper` folder.
- When referencing Factorio runtime objects (e.g., `LuaCustomChartTag`), be aware that static analysis may not recognize all valid runtime fields or methods. Use per-line suppression comments (e.g., `---@diagnostic disable-next-line: undefined-field`) to silence false positives, especially for methods like `:destroy()` or `:destroy_tag()` on chart tags.
- Always be on the lookout for situations that create a "too many C levels" error. Do not try to fix by placing a requires staement in methods - THIS WILL NOT WORK!

---

## File and Module Structure
- Organize code by concern: core logic, cache, GUI, sync tag, tests, etc. Each concern should have its own folder under `core/` or `gui/` as appropriate.
- Place all persistent data helpers in `core/utils/`. These helpers should be surface-aware and multiplayer-safe, and should never access persistent storage directly (always go through the `Cache` module).
- Place all GUI logic in `gui/` and submodules. All GUI modules should use `base_gui.lua` for shared properties and methods, and should follow the idiomatic Factorio GUI style guide (see `factorio_specs.md`).
- Place all test files in `tests/`. Each core module and helper should have a corresponding test file, and all tests should be automated and cover edge cases and multiplayer scenarios.
- All pattern base classes are located in `core/pattern/` or `core/patterns/` and are documented in `notes/pattern_class_notes.md`.
- All domain classes (e.g., `Tag`, `Favorite`, `PlayerFavorites`) are located in their respective folders under `core/` and are strictly annotated and documented.

---

## Persistent Data
- Store all persistent data in `storage`. Never use `_G` or any other global for persistence. The `storage` table is the official, per-mod persistent data table in Factorio 2.0+ and is managed by the game engine.
- Use the `Cache` module for all persistent data access and mutation. The `Cache` module provides a strict, surface-aware, and multiplayer-safe interface for all persistent data operations.
- Use primitive values for persisted storage values. Create helper methods to convert the values back to objects when necessary. Do not store objects in persistent storage! It won't work, as Factorio's serialization only supports primitive types and tables of primitives.
- The persistent data schema is documented in `notes/data_schema.md`. All changes to the schema must be reflected in this document.

---

## Surface Awareness
- All helpers and accessors must take surface context into account. Never assume a single surface or player. All data access and mutation must take surface context into account, and all helper methods must accept surface or player context as parameters where appropriate.
- All persistent and runtime caches are surface-aware. The `Cache` and `Lookups` modules provide methods for managing data on a per-surface basis.

---

## Testing
- All core logic and helpers must be covered by automated tests. Use the `tests/` directory for all test files. Each core module and helper should have a corresponding test file, and all tests should be automated and cover edge cases and multiplayer scenarios.
- Edge cases should be examined in all tests where applicable. Multiplayer scenarios must be tested to ensure correctness and robustness.
- File names in `tests/` should mirror the modules they represent. This makes it easy to find and run tests for any given module.
- If I delete all the files in the tests folder, do not recreate any tests unless I explicitly ask

---

## Documentation
- Update design specs, architecture, and data schema, etc as the project evolves. This should be done every 5-10 iterations, or whenever a major change is made to the codebase.
- If a new style methodology, protocol or system, etc relating to the intricacies of Factorio version 2 modding comes to light in the coding process, add the note after verifying the point into the `factorio_specs.md` file.
- Document all public functions and modules. All public and private fields, as well as all function parameters and return values, must be annotated for IDE support and static analysis.
- Use EmmyLua for formatting. All classes, fields, and methods must be annotated for strictness and IDE support. See `core/types/factorio.emmy.lua` for Factorio runtime types and type aliases.
- When referencing Factorio runtime objects (e.g., `LuaCustomChartTag`), be aware that static analysis may not recognize all valid runtime fields or methods. Use per-line suppression comments (e.g., `---@diagnostic disable-next-line: undefined-field`) to silence false positives, especially for methods like `:destroy()` or `:destroy_tag()` on chart tags.

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
