---
description: "Use when writing PowerShell commands, running terminal commands, or editing .ps1 files in TeleportFavorites. Contains confirmed anti-patterns and correct patterns for this Windows PowerShell environment."
applyTo: "**"
---
# TeleportFavorites PowerShell Development Standards

## Shell Command Formatting
- This project uses **Windows PowerShell** as the default shell.
- Use `;` instead of `&&` for command chaining.
- Use backtick (`` ` ``) for line continuation.
- Use `Get-ChildItem`, `Select-String`, `Where-Object` — NOT `ls`, `grep`, `head`.

## File Organization Rules

**❌ NEVER place test-related files in the root directory:**
- `test_output.txt`, `test_output_latest.txt`, `debug_test_runner.lua`, debug scripts

**✅ CORRECT file placement:**
- Production code: `core/`, `gui/`, `prototypes/`, `graphics/`
- Test files: `tests/specs/`, `tests/output/`, `tests/mocks/`
- Config files: `.vscode/`, `.github/`, `.project/`

## ❌ Confirmed Anti-Patterns

```powershell
# BROKEN: Select-String with -A/-B/-C context parameters on script output
.\.test.ps1 | Select-String -Pattern "Total tests.*:" -A 2
.\.test.ps1 | Select-String -Pattern "Failed|Failures" -A 10
.\.test.ps1 | Select-String -Pattern "Failed|Total tests" -Context 1
# ERROR: Script output creates objects, not strings — context params cannot bind.

# BROKEN: Using Unix && for command chaining
.\.test.ps1 > test_output.txt 2>&1 && Get-Content test_output.txt
# ERROR: "The token '&&' is not a valid statement separator"

# BROKEN: Unix-style commands
ls -la | grep pattern
head -10 file.txt
tail -f log.txt

# BROKEN: lua -c for syntax checking
lua -c tests\specs\file.lua
# ERROR: "-c" is not a valid parameter for lua.exe — shows usage help instead

# BROKEN: Double-nested paths when already in a subdirectory
cd tests; Get-ChildItem "tests\specs\*_spec.lua"
# ERROR: Looks for tests\tests\specs instead of specs

# BROKEN: dir /b in PowerShell pipelines
Set-Location tests; dir /b "specs\*_spec.lua" | Select-String "drag_drop"
# ERROR: "dir /b" is cmd.exe syntax, causes pipeline errors

# BROKEN: Piping script output to Select-String with context parameters
(.\.test.ps1) | Select-String "Overall Test Summary" -A 5
# ERROR: PowerShell script output produces objects, not strings — binding failure
```

## ✅ Correct PowerShell Patterns

```powershell
# CORRECT: Save to file, then read (avoids all pipeline object issues)
.\.test.ps1 > out.txt 2>&1; Get-Content out.txt -Tail 20; Remove-Item out.txt

# CORRECT: Semicolons for chaining
.\.test.ps1; Get-Content "tests\test_output.txt" | Select-String "Overall Test Summary"

# CORRECT: PowerShell-native file search
Get-ChildItem "specs\*_spec.lua"                           # When already in tests/
Get-ChildItem -Path ".\specs\*_spec.lua" -Filter "*drag*"  # Explicit relative path
Get-ChildItem -Recurse | Where-Object { $_.Name -match "pattern" }

# CORRECT: Text replacement in files
(Get-Content "file.lua") -replace "old_pattern", "new_pattern" | Set-Content "file.lua"

# CORRECT: Lua syntax checking
lua -e "loadfile('tests\\specs\\file.lua')"   # Check syntax without executing
lua tests\specs\file.lua                       # Execute file directly

# CORRECT: Out-String before Select-String (no context params)
.\.test.ps1 | Out-String | Select-String -Pattern "Failed"

# CORRECT: Check for empty files
Get-ChildItem "specs\*_spec.lua" | Where-Object {
  (Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue).Trim() -eq ""
}
```
