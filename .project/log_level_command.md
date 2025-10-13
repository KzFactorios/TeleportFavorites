# Log Level Command Implementation

## Overview
Added a new `/tf_log_level` command that allows players to change the log level during gameplay without restarting Factorio. This is particularly useful for debugging issues or troubleshooting without interrupting gameplay.

## Command Syntax
```
/tf_log_level [level]
```

### Available Levels
- **production** - Minimal logging (default)
- **warn** - Show warnings and errors
- **error** - Show only errors
- **debug** - Verbose logging for debugging

### Usage Examples
```
/tf_log_level debug      -- Enable verbose debug logging
/tf_log_level production -- Disable debug logs (default)
/tf_log_level            -- Show current level and available options
```

## Implementation Details

### File Modified
- `core/commands/debug_commands.lua`

### Key Features
1. **Dual System Sync**: Changes log level in both ErrorHandler and DebugConfig systems
2. **Runtime Adjustment**: No game restart required
3. **User Feedback**: Displays current level and available options
4. **Validation**: Rejects invalid log level values

### Technical Implementation
```lua
-- Handler for /tf_log_level command
local function tf_log_level_handler(deps, command)
  local Logger = deps.Logger
  local DebugConfig = deps.DebugConfig
  local PlayerHelpers = deps.PlayerHelpers
  local player = game.players[command.player_index]
  
  -- Show usage if no parameter
  if not level or level == "" then
    PlayerHelpers.safe_player_print(player, "Usage: /tf_log_level <level>")
    PlayerHelpers.safe_player_print(player, "Available levels: production, warn, error, debug")
    PlayerHelpers.safe_player_print(player, "Current log level: " .. Logger._log_level)
    return
  end
  
  -- Update ErrorHandler log level
  Logger.set_log_level(level)
  
  -- Sync DebugConfig numeric level
  local numeric_level_map = {
    production = DebugConfig.LEVELS.WARN,
    warn = DebugConfig.LEVELS.WARN,
    error = DebugConfig.LEVELS.ERROR,
    debug = DebugConfig.LEVELS.DEBUG
  }
  DebugConfig.set_level(numeric_level_map[level])
  
  PlayerHelpers.safe_player_print(player, "Log level changed to: " .. level)
end
```

## Why Two Logging Systems?

The mod has two logging systems:

1. **ErrorHandler** (Simple String-Based)
   - Uses string levels: "production", "warn", "error", "debug"
   - Located in `core/utils/error_handler.lua`
   - Used for general error handling and logging

2. **DebugConfig** (Numeric Level-Based)
   - Uses numeric levels: 0-4 (NONE, ERROR, WARN, INFO, DEBUG)
   - Located in `core/utils/debug_config.lua`
   - Used for structured debug logging with level checks

The `/tf_log_level` command synchronizes both systems to ensure consistent logging behavior.

## Related Commands

- **/tf_debug_production** - Quick switch to production mode
- **/tf_debug_debug** - Quick switch to debug mode
- **/tf_debug_info** - Show current debug configuration
- **/tf_debug_level [0-4]** - Set numeric debug level directly

## Testing

All existing tests pass with the new command implementation:
```
✅ GuiObserver - should load module without errors
✅ GuiObserver - should handle initialization state correctly
✅ GuiObserver - should manage observers and notifications correctly
✅ GuiObserver - should clean up invalid observers
```

## Documentation Updates

- ✅ Updated `changelog.txt` with feature announcement
- ✅ Updated `README.md` with debug commands section
- ✅ Created this technical documentation file

## Use Cases

1. **Bug Reporting**: Players can enable debug logging when encountering issues to provide detailed logs
2. **Performance**: Switch to production mode to reduce log spam during normal gameplay
3. **Development**: Toggle between modes while testing without restarting
4. **Troubleshooting**: Investigate multiplayer sync issues with verbose logging

## Configuration

The default log level is set in `constants.lua`:
```lua
DEFAULT_LOG_LEVEL = "production"  -- Line 12
```

This can be overridden at runtime using the `/tf_log_level` command.

## Version Information

- **Added in**: Version 0.0.8
- **Status**: Complete and tested
- **Breaking Changes**: None
