# TeleportFavorites Development Context

## Environment

- **Operating System**: Windows
- **Default Shell**: PowerShell
- **Language**: Lua
- **Framework**: Factorio Modding API

## Important Notes

### PowerShell Command Formatting

This project uses Windows PowerShell as the default shell. When providing terminal commands, please follow these guidelines:

- **DO NOT** use Bash-style command chaining with `&&`. This is not valid in PowerShell.
- **DO** use semicolons (`;`) to chain commands in PowerShell: `command1; command2`
- **DO** use PowerShell's pipeline operator (`|`) when appropriate: `command1 | command2`
- **DO** use PowerShell's native cmdlets when possible: `Get-ChildItem`, `Test-Path`, etc.
- **DO** access environment variables using `$env:VAR_NAME` syntax

For more details, see [PowerShell Command Format](notes/powershell_command_format.md).

### Project Organization

The project follows a modular organization:
- `core/` - Core functionality modules
- `gui/` - GUI-related code
- `prototypes/` - Factorio prototype definitions
- `notes/` - Documentation and development notes

## Testing

When running tests:
```powershell
cd "v:\Fac2orios\2_Gemini\mods\TeleportFavorites"; lua test_file.lua
```

## Documentation

Important documentation can be found in the `notes/` directory.
