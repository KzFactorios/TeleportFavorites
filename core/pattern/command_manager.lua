---@diagnostic disable: undefined-global

--[[
command_manager.lua
TeleportFavorites Factorio Mod
-----------------------------
Command Manager implementing Command pattern for centralized action handling.

Features:
---------
- Centralized command execution with comprehensive error handling
- Undo/Redo functionality with configurable history limits
- Command queuing and batch execution
- Command validation and state management
- Performance monitoring and execution metrics
- Player-specific command histories

Architecture:
-------------
- Singleton pattern for global command management
- Observer pattern for command execution notifications
- Strategy pattern for different undo/redo strategies
- Facade pattern for simplified command execution API

Usage:
------
local cmd = ToggleFavoriteCommand:new(player, gps, true)
CommandManager:execute(cmd)         -- Execute immediately
CommandManager:undo(player)         -- Undo last command for player
CommandManager:redo(player)         -- Redo last undone command for player
CommandManager:clear_history(player) -- Clear command history for player
--]]

local Singleton = require("core.pattern.singleton")
local Observer = require("core.pattern.observer") 
local ErrorHandler = require("core.utils.error_handler")
local Helpers = require("core.utils.helpers_suite")

---@class CommandManager : Singleton
local CommandManager = setmetatable({}, { __index = Singleton })
CommandManager.__index = CommandManager

--- Maximum number of commands to keep in history per player
local MAX_HISTORY_SIZE = 50

--- Initialize the command manager
function CommandManager:init()
  self.command_histories = {}  -- player_index -> {commands, undo_index}
  self.execution_stats = {
    total_commands = 0,
    successful_commands = 0,
    failed_commands = 0,
    undo_operations = 0,
    redo_operations = 0
  }
  self.observers = Observer:new()
  
  ErrorHandler.debug_log("CommandManager initialized")
end

--- Get command history for a player
---@param player LuaPlayer
---@return table history {commands = {}, undo_index = 0}
function CommandManager:get_player_history(player)
  if not player or not player.valid then
    return { commands = {}, undo_index = 0 }
  end
  
  local player_index = player.index
  if not self.command_histories[player_index] then
    self.command_histories[player_index] = {
      commands = {},
      undo_index = 0  -- Points to the next command to undo
    }
  end
  
  return self.command_histories[player_index]
end

--- Execute a command
---@param command GuiCommand The command to execute
---@return boolean success Whether the command executed successfully
function CommandManager:execute(command)
  if not command then
    ErrorHandler.warn_log("Attempted to execute nil command")
    return false
  end

  if not command.can_execute or not command:can_execute() then
    ErrorHandler.warn_log("Command cannot be executed", { 
      action_type = command.action_type,
      executed = command.executed 
    })
    return false
  end

  -- Record execution attempt
  self.execution_stats.total_commands = self.execution_stats.total_commands + 1
  
  -- Execute the command
  local success = command:execute()
  
  if success then
    self.execution_stats.successful_commands = self.execution_stats.successful_commands + 1
    
    -- Add to command history
    self:add_to_history(command)
    
    -- Notify observers
    self.observers:notify({
      type = "command_executed",
      command = command,
      success = true
    })
    
    ErrorHandler.debug_log("Command executed successfully", {
      action_type = command.action_type,
      player = command.player and command.player.name
    })
  else
    self.execution_stats.failed_commands = self.execution_stats.failed_commands + 1
    
    -- Notify observers
    self.observers:notify({
      type = "command_executed", 
      command = command,
      success = false
    })
    
    ErrorHandler.warn_log("Command execution failed", {
      action_type = command.action_type,
      player = command.player and command.player.name
    })
  end
  
  return success
end

--- Add command to player's history
---@param command GuiCommand
function CommandManager:add_to_history(command)
  if not command.player or not command.player.valid then
    return
  end
  
  local history = self:get_player_history(command.player)
  
  -- Remove any commands after current undo position (if we're in middle of history)
  if history.undo_index < #history.commands then
    for i = history.undo_index + 1, #history.commands do
      history.commands[i] = nil
    end
  end
  
  -- Add new command
  table.insert(history.commands, command)
  history.undo_index = #history.commands
  
  -- Trim history if it exceeds maximum size
  if #history.commands > MAX_HISTORY_SIZE then
    table.remove(history.commands, 1)
    history.undo_index = history.undo_index - 1
  end
  
  ErrorHandler.debug_log("Command added to history", {
    player = command.player.name,
    action_type = command.action_type,
    history_size = #history.commands,
    undo_index = history.undo_index
  })
end

--- Undo the last command for a player
---@param player LuaPlayer
---@return boolean success Whether undo was successful
function CommandManager:undo(player)
  if not player or not player.valid then
    ErrorHandler.warn_log("Cannot undo - invalid player")
    return false
  end
  
  local history = self:get_player_history(player)
  
  if history.undo_index <= 0 then
    Helpers.player_print(player, {"tf-command.nothing_to_undo"})
    return false
  end
  
  local command = history.commands[history.undo_index]
  if not command then
    ErrorHandler.warn_log("No command found at undo index", {
      player = player.name,
      undo_index = history.undo_index
    })
    return false
  end
  
  local success = command:undo()
  
  if success then
    history.undo_index = history.undo_index - 1
    self.execution_stats.undo_operations = self.execution_stats.undo_operations + 1
    
    -- Notify observers
    self.observers:notify({
      type = "command_undone",
      command = command,
      player = player
    })
    
    ErrorHandler.debug_log("Command undone successfully", {
      player = player.name,
      action_type = command.action_type,
      new_undo_index = history.undo_index
    })
  else
    ErrorHandler.warn_log("Failed to undo command", {
      player = player.name,
      action_type = command.action_type
    })
  end
  
  return success
end

--- Redo the next command for a player
---@param player LuaPlayer
---@return boolean success Whether redo was successful
function CommandManager:redo(player)
  if not player or not player.valid then
    ErrorHandler.warn_log("Cannot redo - invalid player")
    return false
  end
  
  local history = self:get_player_history(player)
  
  if history.undo_index >= #history.commands then
    Helpers.player_print(player, {"tf-command.nothing_to_redo"})
    return false
  end
  
  local command = history.commands[history.undo_index + 1]
  if not command then
    ErrorHandler.warn_log("No command found for redo", {
      player = player.name,
      undo_index = history.undo_index
    })
    return false
  end
  
  local success = command:execute()
  
  if success then
    history.undo_index = history.undo_index + 1
    self.execution_stats.redo_operations = self.execution_stats.redo_operations + 1
    
    -- Notify observers
    self.observers:notify({
      type = "command_redone",
      command = command,
      player = player
    })
    
    ErrorHandler.debug_log("Command redone successfully", {
      player = player.name,
      action_type = command.action_type,
      new_undo_index = history.undo_index
    })
  else
    ErrorHandler.warn_log("Failed to redo command", {
      player = player.name,
      action_type = command.action_type
    })
  end
  
  return success
end

--- Clear command history for a player
---@param player LuaPlayer
function CommandManager:clear_history(player)
  if not player or not player.valid then
    return
  end
  
  local player_index = player.index
  self.command_histories[player_index] = {
    commands = {},
    undo_index = 0
  }
  
  ErrorHandler.debug_log("Command history cleared", { player = player.name })
  Helpers.player_print(player, {"tf-command.history_cleared"})
end

--- Get execution statistics
---@return table stats Execution statistics
function CommandManager:get_stats()
  return Helpers.deep_copy(self.execution_stats)
end

--- Check if player can undo
---@param player LuaPlayer
---@return boolean can_undo
function CommandManager:can_undo(player)
  if not player or not player.valid then
    return false
  end
  
  local history = self:get_player_history(player)
  return history.undo_index > 0
end

--- Check if player can redo
---@param player LuaPlayer
---@return boolean can_redo
function CommandManager:can_redo(player)
  if not player or not player.valid then
    return false
  end
  
  local history = self:get_player_history(player)
  return history.undo_index < #history.commands
end

--- Get command history info for a player
---@param player LuaPlayer
---@return table info {total_commands, undo_index, can_undo, can_redo}
function CommandManager:get_history_info(player)
  if not player or not player.valid then
    return { total_commands = 0, undo_index = 0, can_undo = false, can_redo = false }
  end
  
  local history = self:get_player_history(player)
  return {
    total_commands = #history.commands,
    undo_index = history.undo_index,
    can_undo = self:can_undo(player),
    can_redo = self:can_redo(player)
  }
end

--- Register observer for command events
---@param observer table Observer with update method
function CommandManager:add_observer(observer)
  self.observers:attach(observer)
end

--- Cleanup expired player histories
function CommandManager:cleanup_expired_histories()
  local active_players = {}
  for _, player in pairs(game.players) do
    if player.valid then
      active_players[player.index] = true
    end
  end
  
  local cleaned_count = 0
  for player_index, _ in pairs(self.command_histories) do
    if not active_players[player_index] then
      self.command_histories[player_index] = nil
      cleaned_count = cleaned_count + 1
    end
  end
  
  if cleaned_count > 0 then
    ErrorHandler.debug_log("Cleaned up command histories", { count = cleaned_count })
  end
end

return CommandManager
