# PowerShell Command Formatting Guidelines

## Introduction

This document provides guidance for formatting PowerShell commands correctly in this project. Since the project uses Windows PowerShell as the default shell, it's important to follow PowerShell-specific syntax.

## Command Chaining

### Incorrect ❌

```powershell
# Using bash/cmd-style && for command chaining doesn't work in PowerShell
cd "v:\Fac2orios\2_Gemini\mods\TeleportFavorites" && lua -e "package.path"
```

### Correct ✅

```powershell
# Use semicolons to chain commands in PowerShell
cd "v:\Fac2orios\2_Gemini\mods\TeleportFavorites"; lua -e "package.path"

# Or use PowerShell's pipeline operator when applicable
"Text" | ForEach-Object { $_ }

# For multi-line commands, use backticks for line continuation
Get-Process |
  Where-Object { $_.CPU -gt 10 } |
  Select-Object Name, CPU
```

## Conditionals

### Incorrect ❌

```powershell
# Bash style conditionals don't work in PowerShell
if [ -f file.txt ]; then echo "File exists"; fi
```

### Correct ✅

```powershell
# Use PowerShell conditional syntax
if (Test-Path "file.txt") { Write-Host "File exists" }
```

## Environment Variables

### Incorrect ❌

```powershell
# Bash-style $VAR doesn't work for accessing environment variables
echo $PATH
```

### Correct ✅

```powershell
# Use $env: prefix for environment variables
echo $env:PATH
```

## File Paths

Windows file paths use backslashes, though PowerShell accepts forward slashes in most contexts:

```powershell
# Both of these work in PowerShell
cd "v:\Fac2orios\2_Gemini\mods\TeleportFavorites"
cd "v:/Fac2orios/2_Gemini/mods/TeleportFavorites"
```

## Working Directory

### Optimization ⚡

```powershell
# If you're already in the target directory, no CD command is needed
# Unnecessary:
cd "v:\Fac2orios\2_Gemini\mods\TeleportFavorites"; Get-ChildItem

# Better - simply run the command if already in the directory:
Get-ChildItem
```

PowerShell maintains the current working directory between commands, so there's no need to navigate to the current directory again.

## Command Execution

### Incorrect ❌

```powershell
# Bash-style command execution doesn't work in PowerShell
version=$(lua --version)
```

### Correct ✅

```powershell
# Use $() for command execution
$version = (lua --version)
```

## Performance Operations

For operations on large sets of data or files, consider using PowerShell-specific approaches:

```powershell
# Get all Lua files recursively
Get-ChildItem -Path . -Filter *.lua -Recurse

# Use ForEach-Object for processing
Get-ChildItem -Path . -Filter *.lua -Recurse | ForEach-Object {
    $_.FullName
}
```

## Important Notes for AI Tools and Agents

- When generating terminal commands for this workspace, **always use PowerShell syntax**.
- Never use `&&` for command chaining; use semicolons `;` instead.
- For complex operations, prefer native PowerShell cmdlets (Get-ChildItem, Test-Path, etc.) over legacy commands.
- Remember that PowerShell is case-insensitive for command and parameter names, but case-sensitive for variables and values.
