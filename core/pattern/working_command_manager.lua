---@diagnostic disable: undefined-global

--[[
working_command_manager.lua
TeleportFavorites Factorio Mod
-----------------------------
Simple working command manager for GUI commands.
--]]

local ErrorHandler = require("core.utils.error_handler")

---@class WorkingCommandManager
local WorkingCommandManager = {}

-- Singleton instance
local manager_instance = nil

--- Get the command manager instance
---@return table
function WorkingCommandManager.get_instance()
  if not manager_instance then
    manager_instance = {
      histories = {},
      max_size = 10
    }
  end
  return manager_instance
end

--- Execute a command
---@param command table
---@return boolean
function WorkingCommandManager.execute_command(command)
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
    WorkingCommandManager.add_to_history(command)
  end

  return success
end

--- Undo the last command for a player
---@param player LuaPlayer
---@return boolean
function WorkingCommandManager.undo_last_command(player)
  local manager = WorkingCommandManager.get_instance()
  local history = WorkingCommandManager.get_player_history(player)
  
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
    table.remove(history, #history)
    ErrorHandler.debug_log("Command undone successfully", { player = player.name })
  end

  return success
end

--- Get command history for a player
---@param player LuaPlayer
---@return table
function WorkingCommandManager.get_player_history(player)
  local manager = WorkingCommandManager.get_instance()
  local player_index = player.index
  
  if not manager.histories[player_index] then
    manager.histories[player_index] = {}
  end
  
  return manager.histories[player_index]
end

--- Add command to history
---@param command table
function WorkingCommandManager.add_to_history(command)
  local history = WorkingCommandManager.get_player_history(command.player)
  
  table.insert(history, command)
  
  -- Trim history if too large
  local manager = WorkingCommandManager.get_instance()
  if #history > manager.max_size then
    table.remove(history, 1)
  end
end

--- Clean up command history for a player
---@param player_index number
function WorkingCommandManager.cleanup_player_history(player_index)
  local manager = WorkingCommandManager.get_instance()
  manager.histories[player_index] = nil
end

return WorkingCommandManager
