---
title: "Linter & Tooling"
description: "How to run and fix the require-lint, hoist-fixer, pre-commit hooks, and storage sanitizer."
applyTo: "**/*"
---

Purpose
- Document local developer flows for `require` hoisting, storage sanitization, pre-commit hooks, and CI linter jobs.

Quickstart
- Run linter (check-only):
  - `lua .scripts/require_lint.lua --check .`
- Auto-fix hoistable `require()`s:
  - `lua .scripts/require_lint.lua --fix .`
- Install local pre-commit hook (exact commands):
  - POSIX (Linux/macOS/Git Bash):
    - `cp .githooks/pre-commit .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit`
  - PowerShell (Windows):
    - `Copy-Item -Path .githooks\pre-commit -Destination .git\hooks\pre-commit -Force; icacls .git\hooks\pre-commit /grant Everyone:RX`
  - Or run the repository-provided install script if present.

Rules (enforced)
- Note: For global policies such as `require()` placement and no-hoisting, see `.github/copilot-instructions.md`.
- Any table written to `storage` must be sanitized via `Cache.sanitize_for_storage` (or equivalent) to remove userdata/functions and ensure deterministic ordering.

Examples & Fixes
- Move `local serpent = require("serpent")` to top-of-file, or guard debug-only requires with top-level `pcall(require, "serpent")` and an early nil check.
- Replace direct GUI creation (`player.gui.screen.add`) with `GuiBase` helpers.
- Before logging or persisting debug dumps, sanitize objects with `Cache.sanitize_for_storage(obj)`.

CI & Hooks
- CI job: `.github/workflows/require-lint.yml` must run `lua .scripts/require_lint.lua --check .`.
- Pre-commit: `.githooks/pre-commit` runs linter with `--fix`; 

Troubleshooting
- If linter flags a file but `--fix` made no change, inspect for dynamic `require` usage that must be refactored manually.
- If tests fail after fixes, run `.\\.test.ps1` locally and revert only the failing change for manual inspection.
