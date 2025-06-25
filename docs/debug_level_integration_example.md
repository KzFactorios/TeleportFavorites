# Debug Level Controls Integration Guide

This document explains how to use the runtime debug level controls in TeleportFavorites.

## Overview

The mod provides both console commands and GUI controls for changing debug levels during gameplay without requiring restarts.

### Available Debug Levels

- **NONE (0)**: No debug output (production mode)
- **ERROR (1)**: Only critical errors
- **WARN (2)**: Warnings and errors  
- **INFO (3)**: General information logging
- **DEBUG (4)**: Detailed debugging information
- **TRACE (5)**: Maximum verbosity (development only)

## Console Commands

All commands are available immediately when the mod loads:

### `/tf_debug_level <number>`
Set the debug level to a specific value (0-5).

**Examples:**
```
/tf_debug_level 0    # Production mode (no debug output)
/tf_debug_level 2    # Warnings and errors only
/tf_debug_level 4    # Full debugging information
```

### `/tf_debug_info`
Show current debug configuration and available levels.

**Example output:**
```
=== TeleportFavorites Debug Info ===
Current Level: 3 (INFO)
Mode: Development
Available Levels:
  0 = NONE
  1 = ERROR
  2 = WARN
  3 = INFO ← CURRENT
  4 = DEBUG
  5 = TRACE
```

### `/tf_debug_production`
Quick switch to production mode (sets level to WARN).

### `/tf_debug_development` 
Quick switch to development mode (sets level to DEBUG).

## GUI Integration

You can add debug level controls to any GUI using the provided helper functions.

### Adding Debug Controls to a GUI

```lua
local DebugCommands = require("core.commands.debug_commands")

-- In your GUI creation function:
function create_my_gui(player)
  local frame = GuiBase.create_frame(player.gui.screen, "my_gui_frame", "vertical", "dialog_frame")
  
  -- ... other GUI elements ...
  
  -- Add debug controls (optional - could be behind a dev mode check)
  if should_show_debug_controls() then
    local debug_controls = DebugCommands.create_debug_level_controls(frame, player)
    debug_controls.style.margin = {0, 0, 10, 0}  -- Add some spacing
  end
  
  return frame
end

-- Helper function to determine if debug controls should be shown
function should_show_debug_controls()
  -- Could check for development mode, admin status, etc.
  return storage._tf_debug_mode or game.is_demo()
end
```

### GUI Event Handling

The GUI events are automatically handled through the centralized dispatcher. No additional event registration is needed - debug button clicks are automatically routed to `DebugCommands.on_debug_level_button_click()`.

## Code Usage

Use the debug logging throughout your code:

```lua
local Logger = require("core.utils.enhanced_error_handler")

-- These will only output if the current debug level allows them
Logger.error("Critical error occurred", {details = "..."})
Logger.warn("Warning message", {context = "..."})
Logger.info("Informational message", {data = "..."})
Logger.debug("Debug information", {state = "..."})
Logger.trace("Detailed trace info", {execution_path = "..."})
```

## System Architecture

### Debug Configuration (`core.utils.debug_config.lua`)
- Centralized debug level management
- Environment detection (development vs production)
- Level validation and persistence

### Enhanced Error Handler (`core.utils.enhanced_error_handler.lua`)
- Routes logging calls based on current debug level
- Integrates with existing ErrorHandler infrastructure
- Performance-conscious (early returns for disabled levels)

### Debug Commands (`core.commands.debug_commands.lua`)
- Console command registration
- GUI control creation and event handling
- User-friendly level display and switching

## Best Practices

1. **Use appropriate log levels**: Don't use `debug()` for critical errors or `error()` for routine information.

2. **Performance considerations**: Debug calls have minimal overhead when disabled, but avoid complex computations in debug call parameters:
   ```lua
   -- Good: Simple data
   Logger.debug("Processing item", {item_name = item.name})
   
   -- Avoid: Expensive computation that runs even when debug is disabled
   Logger.debug("Complex state", {expensive_calculation = compute_heavy_stats()})
   
   -- Better: Guard expensive operations
   if Logger.should_log(Logger.LEVELS.DEBUG) then
     Logger.debug("Complex state", {expensive_calculation = compute_heavy_stats()})
   end
   ```

3. **User experience**: Consider whether debug controls should be visible to all users or only in development/admin modes.

4. **Documentation**: Include debug level recommendations in your feature documentation.

## Testing

Test the debug system with:

1. **Console commands**: Try all debug level commands in-game
2. **GUI controls**: Create a test GUI with debug controls and verify level changes
3. **Log output**: Verify that messages appear/disappear as expected when changing levels
4. **Performance**: Ensure disabled debug calls have minimal performance impact

## Migration Notes

If you're integrating this into existing code:

1. Replace existing `ErrorHandler.debug_log()` calls with appropriate level-specific Logger calls
2. Consider adding debug level guards around expensive debug computations
3. Update your development workflow to use the new debug commands
4. Test thoroughly with different debug levels to ensure proper behavior
