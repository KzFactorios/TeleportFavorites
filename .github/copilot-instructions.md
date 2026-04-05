# TeleportFavorites: Master Instructions (Hub)

## 1. CRITICAL CONSTRAINTS (FORBIDDEN PATTERNS)

# FATAL ERROR: RUNTIME REQUIRE
- **ABSOLUTELY FORBIDDEN:** Never add `require()` inside any function, event handler, or conditional. This is a build-breaking, non-recoverable error in Factorio mods.
- If you see a require in a non-top-level scope, you must remove it and move it to the top.
- If a symbol is missing, ask the user to clarify or add the require at the top, never inside a function.


- **NO RUNTIME REQUIRES**: `require()` must be at the **absolute top-level** module scope. Factorio 2.0 strictly prohibits `require()` inside functions, loops, or conditional event handlers. Any violation is a fatal error and must be reverted immediately.
- **NO HOISTING**: Lua does not hoist. Define all local functions and tables **BEFORE** they are referenced in the file.
- **STORAGE ONLY**: Target API 2.0+. Use `storage` (The `global` table is deprecated/forbidden).
- **SURGICAL EDITS**: Modify ONLY the requested function or block. Do not refactor or "clean up" surrounding code unless explicitly asked.
## 2. AUTOMATIC SUBSYSTEM CONTEXT
The following instruction modules are auto-loaded based on the file type being edited. Refer to them for implementation details:
- **Lua & API Rules**: `.github/instructions/coding_standards.instructions.md`
- **GUI & Architecture**: `.github/instructions/architecture.instructions.md`
- **Data & Schema**: `.github/instructions/data_schema.instructions.md`
- **Permissions**: `.github/instructions/game_rules.instructions.md`
- **Performance**: `.github/instructions/performance_patterns.instructions.md`
- **Terminal & PowerShell**: `.github/instructions/powershell_standards.instructions.md`
- **Testing & Mocks**: `.github/instructions/testing_standards.instructions.md`

## 3. PROJECT-WIDE DOMAIN KNOWLEDGE
- **Core Intent**: High-speed teleportation via favorites bar and map tags.
- **Constraints**: Teleportation is allowed from Map and Remote View. **No favorites allowed on Space Platforms.**
- **GUI Naming**: All GUI elements MUST be named with the `tp_fav_` prefix.
- **Ownership**: Follow the strict creator-based ownership model defined in `game_rules`.
- **Roadmap**: Consult `.github/instructions/todo.instructions.md` for current tasks and tech debt.

## 4. WORKFLOW & SAFETY
- **Ambiguity**: If a request lacks context or conflicts with these rules, **ASK** for clarification before generating code.
- **PowerShell**: Use `Out-String` when piping script output to avoid object-binding errors in the terminal.
- **Performance Check**: Always reference `performance_patterns` before implementing `on_nth_tick` or loop-heavy logic.