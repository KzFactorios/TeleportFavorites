---
title: "Copilot instructions"
description: "Canonical project guidance for AI agents and contributors"
scope: "global"
---

# Require statement policy (critical)

**All** `require()` calls must be at the top of every Lua file, before any logic, function, or variable definitions.

- Keep all `require()` calls at top-level, grouped and ordered consistently.
- Do not call `require()` inside functions, event handlers, conditionals, loops, or after module initialization. Factorio will error: "Require can't be used outside of control.lua parsing."
- Prefer extracting shared logic into a helper module (for example `core/utils/basic_helpers.lua`).
- If refactoring is not viable, use lazy-loading inside runtime functions only as a last resort.

**Notes**:

- **No hoisting:** Lua does not hoist. Define all local functions and tables **before** they are referenced in the file.
- **Storage only:** Target API v2.0+. Use `storage` (the `global` table is deprecated/forbidden).
- **Surgical edits:** Modify only the requested function or block. Do not refactor or "clean up" surrounding code unless explicitly asked.


## Core rules

- **Safety first:** avoid runtime-breaking changes.
- Fix root causes; keep edits focused and minimal.
- Add or update tests and run the test suite locally before committing.
- Use EmmyLua annotations for public APIs.
- Do not use emojis or decorative symbols in repository docs or instruction files.


## Key conventions

- **Storage is the source of truth:** use `core/cache/*` helpers rather than reading GUI state.
- Follow Factorio v2.0+ patterns: surface-aware storage and event-driven handlers.


## Workflow notes

- Reference canonical docs in `.github/copilot-instructions.md` and `.project/*` as needed.
- Keep documentation concise; update docs only when behavior or architecture changes.
- Define helper functions and supporting tables before code that references them.


## Related instructions

The following scoped instruction files live under `.github/instructions/` and contain targeted rules and patterns referenced by this document:

- [TeleportFavorites Architecture](.github/instructions/architecture.instructions.md)
- [TeleportFavorites Coding Standards](.github/instructions/coding-standards.instructions.md)
- [TeleportFavorites Data Schema](.github/instructions/data-schema.instructions.md)
- [TeleportFavorites Game Rules](.github/instructions/game-rules.instructions.md)
- [Linter & Tooling](.github/instructions/linter-tooling.instructions.md)
- [TeleportFavorites Performance Patterns](.github/instructions/performance-patterns.instructions.md)
- [TeleportFavorites PowerShell Standards](.github/instructions/powershell-standards.instructions.md)
- [TeleportFavorites Testing Standards](.github/instructions/testing-standards.instructions.md)
- [Beast Mode](.github/instructions/beast-mode.instructions.md)
- `TODO.instructions.md` (intentionally preserved as an empty placeholder)


## Project-wide domain knowledge

- **Core intent:** High-speed teleportation via favorites bar and map tags.
- **Constraints:** Teleportation is allowed from Map and Remote View. No favorites allowed on Space Platforms.
- **Ownership:** Follow the strict creator-based ownership model defined in `game-rules`.
- **PowerShell:** Use `Out-String` when piping script output to avoid object-binding errors.
- **Performance check:** Always reference `performance-patterns` before implementing `on_nth_tick` or loop-heavy logic.

- Use `Cache.sanitize_for_storage` in [core/cache/cache.lua](core/cache/cache.lua) to sanitize tables before writing them to `storage` (no userdata/functions allowed).
