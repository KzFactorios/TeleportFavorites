---@diagnostic disable: undefined-global

--[[
gui_command.lua
TeleportFavorites Factorio Mod
-----------------------------
Concrete Command pattern implementation for GUI event handling.

Command pattern provides:
- Encapsulated actions as objects 
- Undo/redo functionality
- Command validation and error handling
- Centralized execution logging
--]]

local Command = require("core.pattern.command")
local Cache = require("core.cache.cache")
local PlayerFavorites = require("core.favorite.player_favorites")
local Tag = require("core.tag.tag")
local Helpers = require("core.utils.helpers_suite")
local ErrorHandler = require("core.utils.error_handler")

---@class GuiCommand : Command
---@field player LuaPlayer?
---@field action_type string
---@field timestamp number
---@field executed boolean
---@field previous_state table?
local GuiCommand = setmetatable({}, { __index = Command })
GuiCommand.__index = GuiCommand

--- Base constructor for GUI commands
---@param player LuaPlayer
---@param action_type string
---@return GuiCommand
function GuiCommand:new(player, action_type)
  local obj = Command:new()
  setmetatable(obj, self)
  obj.player = player
  obj.action_type = action_type
  obj.timestamp = game.tick
  obj.executed = false
  obj.previous_state = nil
  return obj
end
  obj.executed = false
  obj.previous_state = nil
  return obj
end

--- Execute command with validation and error handling
function GuiCommand:execute()
  if self.executed then
    ErrorHandler.warn_log("Command already executed", { action_type = self.action_type })
    return false
  end

  if not self.player or not self.player.valid then
    ErrorHandler.handle_error(ErrorHandler.error(
      ErrorHandler.ERROR_TYPES.VALIDATION_FAILED,
      "Invalid player for command execution",
      { action_type = self.action_type }
    ), nil, false)
    return false
  end

  -- Store state before execution for undo support
  self.previous_state = self:capture_state()
  
  local success, result = pcall(function()
    return self:_execute_impl()
  end)

  if success and result then
    self.executed = true
    ErrorHandler.debug_log("Command executed successfully", { 
      action_type = self.action_type,
      player = self.player.name
    })
    return true
  else
    ErrorHandler.handle_error(ErrorHandler.error(
      ErrorHandler.ERROR_TYPES.OPERATION_FAILED,
      "Command execution failed: " .. tostring(result),
      { action_type = self.action_type, player = self.player.name }
    ), self.player)
    return false
  end
end

--- Undo command if it was executed
function GuiCommand:undo()
  if not self.executed then
    ErrorHandler.warn_log("Cannot undo command that was not executed", { action_type = self.action_type })
    return false
  end

  if not self.previous_state then
    ErrorHandler.warn_log("Cannot undo command - no previous state captured", { action_type = self.action_type })
    return false
  end

  local success, result = pcall(function()
    return self:_undo_impl()
  end)

  if success and result then
    self.executed = false
    ErrorHandler.debug_log("Command undone successfully", { 
      action_type = self.action_type,
      player = self.player.name
    })
    return true
  else
    ErrorHandler.handle_error(ErrorHandler.error(
      ErrorHandler.ERROR_TYPES.OPERATION_FAILED,
      "Command undo failed: " .. tostring(result),
      { action_type = self.action_type, player = self.player.name }
    ), self.player)
    return false
  end
end

--- Capture current state for undo support (override in subclasses)
function GuiCommand:capture_state()
  return {}
end

--- Implementation method (override in subclasses)
function GuiCommand:_execute_impl()
  error("GuiCommand:_execute_impl() must be implemented by subclass")
end

--- Undo implementation method (override in subclasses)
function GuiCommand:_undo_impl()
  error("GuiCommand:_undo_impl() must be implemented by subclass")
end

--- Check if command can be executed
function GuiCommand:can_execute()
  return self.player and self.player.valid and not self.executed
end

--- Check if command can be undone
function GuiCommand:can_undo()
  return self.executed and self.previous_state ~= nil
end

---@class ToggleFavoriteCommand : GuiCommand
local ToggleFavoriteCommand = setmetatable({}, { __index = GuiCommand })
ToggleFavoriteCommand.__index = ToggleFavoriteCommand

--- Create toggle favorite command
---@param player LuaPlayer
---@param gps string GPS coordinate string
---@param add_favorite boolean True to add, false to remove
---@return ToggleFavoriteCommand
function ToggleFavoriteCommand:new(player, gps, add_favorite)
  local obj = GuiCommand:new(player, "toggle_favorite")
  setmetatable(obj, self)
  obj.gps = gps
  obj.add_favorite = add_favorite
  return obj
end

function ToggleFavoriteCommand:capture_state()
  local favorites = PlayerFavorites.new(self.player)
  return {
    was_favorite = favorites:is_favorited(self.gps),
    favorites_snapshot = Helpers.deep_copy(favorites.favorites)
  }
end

function ToggleFavoriteCommand:_execute_impl()
  local favorites = PlayerFavorites.new(self.player)
  
  if self.add_favorite then
    local success = favorites:add_favorite(self.gps)
    if success then
      Helpers.player_print(self.player, {"tf-command.favorite_added"})
      return true
    else
      return false, "Failed to add favorite"
    end
  else
    local success = favorites:remove_favorite(self.gps)
    if success then
      Helpers.player_print(self.player, {"tf-command.favorite_removed"})
      return true
    else
      return false, "Failed to remove favorite"
    end
  end
end

function ToggleFavoriteCommand:_undo_impl()
  -- Restore previous favorites state
  local player_data = Cache.get_player_data(self.player)
  player_data.favorites = self.previous_state.favorites_snapshot
  
  local action = self.add_favorite and "addition" or "removal"
  Helpers.player_print(self.player, {"tf-command.favorite_undone", action})
  return true
end

---@class UpdateTagTextCommand : GuiCommand
local UpdateTagTextCommand = setmetatable({}, { __index = GuiCommand })
UpdateTagTextCommand.__index = UpdateTagTextCommand

--- Create update tag text command
---@param player LuaPlayer
---@param gps string GPS coordinate string
---@param new_text string New tag text
---@param new_icon table? New tag icon
---@return UpdateTagTextCommand
function UpdateTagTextCommand:new(player, gps, new_text, new_icon)
  local obj = GuiCommand:new(player, "update_tag_text")
  setmetatable(obj, self)
  obj.gps = gps
  obj.new_text = new_text or ""
  obj.new_icon = new_icon or {}
  return obj
end

function UpdateTagTextCommand:capture_state()
  local tag = Cache.get_tag_by_gps(self.gps)
  return {
    previous_text = tag and tag.text or "",
    previous_icon = tag and tag.icon or {},
    tag_existed = tag ~= nil
  }
end

function UpdateTagTextCommand:_execute_impl()
  local tag = Cache.get_tag_by_gps(self.gps) or Tag.new(self.gps, {})
  tag.text = self.new_text
  tag.icon = self.new_icon
  
  -- Update chart tag if it exists
  if tag.chart_tag and tag.chart_tag.valid then
    tag.chart_tag.text = self.new_text
    tag.chart_tag.icon = self.new_icon
  end
  
  -- Save tag back to cache
  local surface_tags = Cache.get_surface_tags(self.player.surface.index)
  surface_tags[self.gps] = tag
  
  Helpers.player_print(self.player, {"tf-command.tag_updated"})
  return true
end

function UpdateTagTextCommand:_undo_impl()
  if not self.previous_state.tag_existed then
    -- Tag didn't exist before, remove it
    local surface_tags = Cache.get_surface_tags(self.player.surface.index)
    surface_tags[self.gps] = nil
  else
    -- Restore previous text and icon
    local tag = Cache.get_tag_by_gps(self.gps)
    if tag then
      tag.text = self.previous_state.previous_text
      tag.icon = self.previous_state.previous_icon
      
      if tag.chart_tag and tag.chart_tag.valid then
        tag.chart_tag.text = self.previous_state.previous_text
        tag.chart_tag.icon = self.previous_state.previous_icon
      end
    end
  end
  
  Helpers.player_print(self.player, {"tf-command.tag_reverted"})
  return true
end

---@class TeleportCommand : GuiCommand
local TeleportCommand = setmetatable({}, { __index = GuiCommand })
TeleportCommand.__index = TeleportCommand

--- Create teleport command
---@param player LuaPlayer
---@param target_gps string Target GPS coordinate
---@return TeleportCommand
function TeleportCommand:new(player, target_gps)
  local obj = GuiCommand:new(player, "teleport")
  setmetatable(obj, self)
  obj.target_gps = target_gps
  return obj
end

function TeleportCommand:capture_state()
  return {
    previous_position = self.player.position,
    previous_surface = self.player.surface.index
  }
end

function TeleportCommand:_execute_impl()
  local result = Tag.teleport_player_with_messaging(self.player, self.target_gps)
  return result == require("constants").enums.return_state.SUCCESS
end

function TeleportCommand:_undo_impl()
  -- Teleport back to previous position
  local success = Helpers.safe_teleport(self.player, self.previous_state.previous_position, self.previous_state.previous_surface)
  if success then
    Helpers.player_print(self.player, {"tf-command.teleport_reverted"})
    return true
  else
    return false, "Failed to revert teleport"
  end
end

-- Export command classes
return {
  GuiCommand = GuiCommand,
  ToggleFavoriteCommand = ToggleFavoriteCommand,
  UpdateTagTextCommand = UpdateTagTextCommand,
  TeleportCommand = TeleportCommand
}
