---
name: "Linter & Tooling"
description: "How to run and fix the require-lint, hoist-fixer, pre-commit hooks, and storage sanitizer."
applyTo: "**/*"
---

Purpose
- Document local developer flows for `require` hoisting, storage sanitization, pre-commit hooks, and CI linter jobs.

Quickstart
- Run linter (check-only):
  - `lua scripts/require_lint.lua --check .`
- Auto-fix hoistable `require()`s:
  - `lua scripts/require_lint.lua --fix .`
- Install local pre-commit hook:
  - Copy `.githooks/pre-commit` into `.git/hooks/pre-commit` (or run the repo-provided install script if present).

Rules (enforced)
- `require()` must appear only at top-level module scope. Runtime/conditional `require()` is forbidden and will be flagged.
- `data/core/lualib` is explicitly excluded from repo lint/fix and must not be modified; pre-commit will reject staged changes under that path.
- Any table written to `storage` must be sanitized via `Cache.sanitize_for_storage` (or equivalent) to remove userdata/functions and ensure deterministic ordering.

Examples & Fixes
- Move `local serpent = require("serpent")` to top-of-file, or guard debug-only requires with top-level `pcall(require, "serpent")` and an early nil check.
- Replace direct GUI creation (`player.gui.screen.add`) with `GuiBase` helpers.
- Before logging or persisting debug dumps, sanitize objects with `Cache.sanitize_for_storage(obj)`.

CI & Hooks
- CI job: `.github/workflows/require-lint.yml` must run `lua scripts/require_lint.lua --check .`.
- Pre-commit: `.githooks/pre-commit` runs linter with `--fix`; it also aborts if staged changes include `data/core/lualib`.

Troubleshooting
- If linter flags a file but `--fix` made no change, inspect for dynamic `require` usage that must be refactored manually.
- If tests fail after fixes, run `.\\.test.ps1` locally and revert only the failing change for manual inspection.
