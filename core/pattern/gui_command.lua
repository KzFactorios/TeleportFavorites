---@diagnostic disable: undefined-global

--[[
gui_command.lua
TeleportFavorites Factorio Mod
-----------------------------
Simplified Command pattern implementation for GUI operations.
--]]

local Cache = require("core.cache.cache")
local PlayerFavorites = require("core.favorite.player_favorites")
local Helpers = require("core.utils.helpers_suite")

---@class GuiCommand
---@field player LuaPlayer
---@field action_type string
---@field executed boolean
---@field previous_state table?
local GuiCommand = {}
GuiCommand.__index = GuiCommand

--- Base constructor for GUI commands
---@param player LuaPlayer
---@param action_type string
---@return GuiCommand
function GuiCommand:new(player, action_type)
  local obj = setmetatable({}, self)
  obj.player = player
  obj.action_type = action_type
  obj.executed = false
  obj.previous_state = nil
  return obj
end

--- Execute command
---@return boolean success
function GuiCommand:execute()
  if self.executed then return false end
  if not self.player or not self.player.valid then return false end

  self.previous_state = self:capture_state()
  local success = self:_execute_impl()
  if success then
    self.executed = true
  end
  return success
end

--- Undo command
---@return boolean success  
function GuiCommand:undo()
  if not self.executed or not self.previous_state then return false end
  local success = self:_undo_impl()
  if success then
    self.executed = false
  end
  return success
end

--- Capture state (override in subclasses)
---@return table
function GuiCommand:capture_state()
  return {}
end

--- Execute implementation (override in subclasses)
---@return boolean
function GuiCommand:_execute_impl()
  return true
end

--- Undo implementation (override in subclasses)
---@return boolean
function GuiCommand:_undo_impl()
  return true
end

---@class ToggleFavoriteCommand : GuiCommand
---@field gps string
---@field add_favorite boolean
local ToggleFavoriteCommand = setmetatable({}, { __index = GuiCommand })
ToggleFavoriteCommand.__index = ToggleFavoriteCommand

---@param player LuaPlayer
---@param gps string
---@param add_favorite boolean
---@return ToggleFavoriteCommand
function ToggleFavoriteCommand:new(player, gps, add_favorite)
  local obj = GuiCommand:new(player, "toggle_favorite")
  setmetatable(obj, self)
  obj.gps = gps
  obj.add_favorite = add_favorite
  return obj
end

function ToggleFavoriteCommand:_execute_impl()
  local favorites = PlayerFavorites.new(self.player)
  if self.add_favorite then
    local success, _ = favorites:add_favorite(self.gps)
    return success ~= nil
  else
    local success, _ = favorites:remove_favorite(self.gps)
    return success == true
  end
end

-- Export
return {
  GuiCommand = GuiCommand,
  ToggleFavoriteCommand = ToggleFavoriteCommand
}
