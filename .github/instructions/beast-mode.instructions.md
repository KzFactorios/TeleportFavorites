---
title: "Beast Mode"
description: "Concise agent instructions; require-statement policy first."
layout: instructions
tags: [agent, policy]
applyTo: "**/*"
---

## Core Behavior

Work autonomously until the user's request is completely resolved. Do not yield back to the user mid-task unless you are genuinely blocked.

- **Standard Adherence**: Before proposing any change, verify it against the relevant `.instructions.md` in `.github/instructions/`. 
- **Think before acting**: Understand the problem fully. Trace the data flow from `storage` to the GUI before writing a single line.
- **Plan with a todo list**: Break work into concrete, verifiable steps.
- **No Half-Measures**: If you state you are going to take an action, perform it immediately. 
- **Surgical Precision**: Focus only on the requested change to avoid breaking established v2.0 patterns.

## Resume & Recovery

- **Resume**: If the user says "resume" or "continue", find the most recent todo list, identify the first unchecked item, and proceed immediately.
- **Self-Correction**: If a Factorio API call fails or a Lua error occurs, re-read the relevant `architecture` or `data_schema` instructions before attempting a second fix.

## Planning & Investigation

Before writing code:
1. **Deep Trace**: Investigate the codebase. Read relevant files and trace dependencies (e.g., if changing a tag, check `core/cache/lookups.lua`).
2. **Standard Check**: Identify which `.instructions.md` files apply to this task.
3. **Run Linter/Tooling**: Run `lua scripts/require_lint.lua --check <path>` to detect runtime `require()` violations. Use `--fix` to apply conservative hoists; manual review is required for ambiguous cases. When tracing storage flows, reference `Cache.sanitize_for_storage` in [core/cache/cache.lua](core/cache/cache.lua) and ensure sanitizer calls on every write to `storage`.
4. **Todo List**: Create concrete steps. **Tag each step** with the intended file (e.g., `[ ] Step 1: Update storage schema in cache.lua`).
4. **Reflect**: After each step, verify the change didn't break the "Source of Truth" (storage).

## Web Research

Use `fetch_webpage` for:
- **Factorio 2.0 API**: Verify current documentation for new 2.0 prototypes or Lua API changes (e.g., Space Age specific classes).
- **Third-party Mods**: Research potential conflicts if the task involves multiplayer or compatibility.
- **Search Priority**: Try Google first, then Bing. Do not search for internal codebase logic.

## Making Code Changes

Note: For global policies such as `require()` placement, no-hoisting, and other contributor constraints, see `.github/copilot-instructions.md`.
- **Incrementalism**: One logical change at a time. Verify the "Vibe" and syntax before moving to the next block.
- **Context Re-read**: If a code patch fails, re-read the file to check for local variable declarations (no hoisting!).
- CRITICAL: Do not generate summary/documentation files or "refactor for cleanliness" unless specifically instructed. Stay surgical.

## Debugging & Testing

- **Root Cause**: Determine why a bug exists in the `storage` or `event` logic before changing the GUI symptoms.
- **Testing**: 
    - Refer to `testing_standards.instructions.md` for spec formatting.
    - Run existing test suites for the modified module.
    - **Edge Cases**: Always test for "Player Disconnected," "Surface Changed," and "Invalid Object" (.valid check).

## Todo Lists

Use markdown checkbox format only. 
- [ ] Step 1: [Module] Action description
- [x] Step 2: [Module] Completed action



