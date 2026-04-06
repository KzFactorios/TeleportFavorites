---
name: "TeleportFavorites PowerShell Standards"
description: "Windows-specific terminal commands and anti-patterns"
applyTo: "**/*.ps1"
---


# TeleportFavorites: PowerShell Standards (Windows)

## 1. TERMINAL SYNTAX MAPPING
- **Chaining**: Use `;` (NEVER `&&`).
- **Continuation**: Use backtick (`` ` ``).
- **Search**: Use `Get-ChildItem` / `Select-String` (NEVER `ls`, `grep`).
- **Reading**: Use `Get-Content -Tail X` (NEVER `tail`).

## 2. CRITICAL ANTI-PATTERNS
- **Select-String**: Fails context params (`-A`, `-B`) on raw script output. Pipe to `Out-String` first.
- **Lua Syntax**: `lua -c` is invalid. Use `lua -e "loadfile('path/to/file.lua')"` for syntax checks.

## 3. RECOMMENDED COMMANDS
- **Test Review**: `.\.test.ps1 > out.txt 2>&1; Get-Content out.txt -Tail 20; Remove-Item out.txt`
- **File Regex**: `(Get-Content "file.lua") -replace "old", "new" | Set-Content "file.lua"`

## 4. CHANGELOG & PACKAGING
- **Format**: Factorio strictly requires: `Version: 0.0.0`, `Date: YYYY-MM-DD`, and category headers (`Features:`, `Bugfixes:`, etc.).
- **Validation**: Before finishing a task, run the changelog validation script if available.
- **Vibe**: If asked to update the changelog, match the existing indentation (usually 2 spaces for entries) exactly.