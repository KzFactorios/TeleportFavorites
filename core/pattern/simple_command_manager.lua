---@diagnostic disable: undefined-global

--[[
simple_command_manager.lua
TeleportFavorites Factorio Mod
-----------------------------
Simple command manager for handling GUI commands.

This provides:
- Command execution with error handling
- Basic undo/redo functionality
- Command history per player
- Automatic cleanup on player disconnect
--]]

local ErrorHandler = require("core.utils.error_handler")

---@class SimpleCommandManager
---@field command_history table<number, table> Player index to command history
---@field max_history_size number Maximum commands to keep in history
local SimpleCommandManager = {}
SimpleCommandManager.__index = SimpleCommandManager

-- Singleton instance
local instance = nil

--- Get the singleton command manager instance
---@return SimpleCommandManager
function SimpleCommandManager:get_instance()
  if not instance then
    instance = setmetatable({
      command_history = {},
      max_history_size = 10
    }, self)
  end
  return instance
end

--- Execute a command
---@param command table Command object with execute method
---@return boolean success
function SimpleCommandManager:execute_command(command)
  if not command or not command.execute then
    ErrorHandler.warn_log("Invalid command - missing execute method")
    return false
  end

  if not command.player or not command.player.valid then
    ErrorHandler.warn_log("Invalid player for command execution")
    return false
  end

  local success = command:execute()
  
  if success then
    -- Add to command history
    self:_add_to_history(command)
  end

  return success
end

--- Undo the last command for a player
---@param player LuaPlayer
---@return boolean success
function SimpleCommandManager:undo_last_command(player)
  local history = self:_get_player_history(player)
  
  if #history == 0 then
    ErrorHandler.debug_log("No commands to undo", { player = player.name })
    return false
  end

  local last_command = history[#history]
  if not last_command.undo then
    ErrorHandler.warn_log("Last command does not support undo", { player = player.name })
    return false
  end

  local success = last_command:undo()
  
  if success then
    -- Remove from history since it's been undone
    table.remove(history, #history)
    ErrorHandler.debug_log("Command undone successfully", { player = player.name })
  end

  return success
end

--- Get command history for a player
---@param player LuaPlayer
---@return table
function SimpleCommandManager:_get_player_history(player)
  local player_index = player.index
  
  -- Initialize history table if it doesn't exist
  if not self.command_history then
    self.command_history = {}
  end
  
  if not self.command_history[player_index] then
    self.command_history[player_index] = {}
  end
  
  return self.command_history[player_index]
end

--- Add command to history
---@param command table
function SimpleCommandManager:_add_to_history(command)
  local history = self:_get_player_history(command.player)
  
  -- Add to end of history
  table.insert(history, command)
  
  -- Trim history if too large
  if #history > self.max_history_size then
    table.remove(history, 1)
  end
end

--- Clean up command history for a player (call on disconnect)
---@param player_index number
function SimpleCommandManager:cleanup_player_history(player_index)
  self.command_history[player_index] = nil
end

--- Get command history size for a player
---@param player LuaPlayer
---@return number
function SimpleCommandManager:get_history_size(player)
  local history = self:_get_player_history(player)
  return #history
end

return SimpleCommandManager
