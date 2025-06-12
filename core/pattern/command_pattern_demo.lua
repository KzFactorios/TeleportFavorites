---@diagnostic disable: undefined-global

--[[
command_pattern_demo.lua
TeleportFavorites Factorio Mod
-----------------------------
Demonstration of Command pattern adoption and usage.

This file shows how the Command pattern has been successfully integrated into
the TeleportFavorites mod to improve code quality and provide undo functionality.

## Pattern Adoption Summary

### Before: Direct GUI Handling
```lua
-- Old approach - direct function calls
local function on_gui_closed(event)
  local player = game.get_player(event.player_index)
  if tag_editor_frame then
    control_tag_editor.close_tag_editor(player)  -- No undo capability
  end
end
```

### After: Command Pattern Implementation  
```lua
-- New approach - Command pattern with undo support
local function on_gui_closed(event)
  local player = game.get_player(event.player_index)
  if tag_editor_frame then
    local close_command = CloseGuiCommand:new(player, "tag_editor")
    WorkingCommandManager.execute_command(close_command)
    -- Player can now undo this action with Ctrl+Z!
  end
end
```

## Benefits Achieved

1. **Undo/Redo Functionality**: Players can undo GUI close actions
2. **Centralized Command Management**: All commands go through one manager
3. **Error Handling**: Commands include validation and error recovery
4. **History Tracking**: Command history per player with configurable limits
5. **Extensibility**: Easy to add new command types

## Usage Examples

### Execute a Command
```lua
local close_command = CloseGuiCommand:new(player, "tag_editor")
local success = WorkingCommandManager.execute_command(close_command)
```

### Undo Last Action
```lua
local success = WorkingCommandManager.undo_last_command(player)
```

### Keyboard Shortcut Integration
The mod now includes Ctrl+Z support for undoing GUI actions:
- Custom input "tf-undo-last-action" registered in data.lua
- Handler in custom_input_dispatcher.lua routes to undo functionality
- Localized feedback messages for user interaction

## Files Modified for Pattern Adoption

### New Pattern Files
- core/pattern/close_gui_command.lua: CloseGuiCommand implementation
- core/pattern/working_command_manager.lua: Command manager with undo support

### Integration Points
- core/events/on_gui_closed_handler.lua: Uses Command pattern for GUI closes
- core/events/custom_input_dispatcher.lua: Added Ctrl+Z undo handler
- data.lua: Added tf-undo-last-action custom input
- locale/en/strings.cfg: Added command feedback messages

### Future Expansion
The pattern can easily be extended to support additional commands:
- ToggleFavoriteCommand: Add/remove favorites with undo
- UpdateTagCommand: Tag modifications with revert capability  
- TeleportCommand: Player teleportation with return functionality
- BatchCommand: Multiple operations as single undoable unit

## Architecture Benefits

The Command pattern adoption demonstrates several architectural improvements:

1. **Separation of Concerns**: Command objects encapsulate specific actions
2. **Single Responsibility**: Each command handles one type of operation
3. **Open/Closed Principle**: Easy to add new commands without changing existing code
4. **Strategy Pattern**: Different undo strategies for different command types
5. **Observer Pattern**: Command manager can notify observers of command execution

This represents a successful evolution from procedural event handling to 
object-oriented command-based architecture.
--]]

local WorkingCommandManager = require("core.pattern.working_command_manager")
local CloseGuiCommand = require("core.pattern.close_gui_command")

local CommandDemo = {}

--- Demonstrate command execution with error handling
---@param player LuaPlayer
---@param gui_name string
---@return boolean success
function CommandDemo.demo_command_execution(player, gui_name)
  -- Create and execute a command
  local command = CloseGuiCommand:new(player, gui_name)
  local success = WorkingCommandManager.execute_command(command)
  
  if success then
    player.print("[Demo] Command executed successfully - you can undo with Ctrl+Z")
  else
    player.print("[Demo] Command execution failed")
  end
  
  return success
end

--- Demonstrate undo functionality
---@param player LuaPlayer
---@return boolean success
function CommandDemo.demo_undo(player)
  local success = WorkingCommandManager.undo_last_command(player)
  
  if success then
    player.print("[Demo] Last action undone successfully")
  else
    player.print("[Demo] No actions to undo")
  end
  
  return success
end

--- Show command history stats for a player
---@param player LuaPlayer
function CommandDemo.show_command_stats(player)
  local history = WorkingCommandManager.get_player_history(player)
  player.print("[Demo] Command history size: " .. #history)
  
  if #history > 0 then
    local last_command = history[#history]
    player.print("[Demo] Last command: " .. (last_command.gui_name or "unknown"))
  end
end

return CommandDemo
