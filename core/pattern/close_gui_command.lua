---@diagnostic disable: undefined-global

--[[
close_gui_command.lua
TeleportFavorites Factorio Mod
-----------------------------
Command pattern implementation for GUI close operations.

This demonstrates the Command pattern in action by:
- Encapsulating GUI close actions as command objects
- Providing undo capability for reopening closed GUIs
- Centralizing validation and logging
- Enabling command history tracking
--]]

local Cache = require("core.cache.cache")
local control_tag_editor = require("core.control.control_tag_editor")
local ErrorHandler = require("core.utils.error_handler")
local Helpers = require("core.utils.helpers_suite")

---@class CloseGuiCommand
---@field player LuaPlayer
---@field gui_name string
---@field gui_data table|nil
---@field executed boolean
local CloseGuiCommand = {}
CloseGuiCommand.__index = CloseGuiCommand

--- Create a new close GUI command
---@param player LuaPlayer
---@param gui_name string Name of the GUI to close
---@return CloseGuiCommand
function CloseGuiCommand:new(player, gui_name)
  local obj = setmetatable({
    player = player,
    gui_name = gui_name,
    gui_data = nil,
    executed = false
  }, self)
  return obj
end

--- Execute the close command
---@return boolean success
function CloseGuiCommand:execute()
  if self.executed then
    ErrorHandler.warn_log("Close command already executed", { gui_name = self.gui_name })
    return false
  end

  if not self.player or not self.player.valid then
    ErrorHandler.warn_log("Invalid player for close command", { gui_name = self.gui_name })
    return false
  end

  -- Capture GUI state before closing for potential undo
  self:_capture_gui_state()

  -- Execute the actual close operation
  local success = self:_perform_close()
  
  if success then
    self.executed = true
    ErrorHandler.debug_log("GUI closed successfully", { 
      gui_name = self.gui_name,
      player = self.player.name
    })
  end

  return success
end

--- Undo the close operation by reopening the GUI
---@return boolean success
function CloseGuiCommand:undo()
  if not self.executed then
    ErrorHandler.warn_log("Cannot undo - close command not executed", { gui_name = self.gui_name })
    return false
  end

  if not self.gui_data then
    ErrorHandler.warn_log("Cannot undo - no GUI state captured", { gui_name = self.gui_name })
    return false
  end

  local success = self:_perform_reopen()
  
  if success then
    self.executed = false
    ErrorHandler.debug_log("GUI reopened successfully", { 
      gui_name = self.gui_name,
      player = self.player.name
    })
  end

  return success
end

--- Capture GUI state before closing
function CloseGuiCommand:_capture_gui_state()
  if self.gui_name == "tag_editor" then
    -- Capture tag editor specific data
    self.gui_data = Cache.get_tag_editor_data(self.player)
  elseif self.gui_name == "data_viewer" then
    -- Capture data viewer specific data
    local player_data = Cache.get_player_data(self.player)
    self.gui_data = {
      active_tab = player_data.data_viewer_active_tab,
      font_size = player_data.data_viewer_font_size
    }
  end
end

--- Perform the actual close operation
---@return boolean success
function CloseGuiCommand:_perform_close()
  if self.gui_name == "tag_editor" then
    local success, err = pcall(control_tag_editor.close_tag_editor, self.player)
    return success
  elseif self.gui_name == "data_viewer" then
    -- Add data viewer close logic when implemented
    return true
  end
  
  return false
end

--- Perform the reopen operation
---@return boolean success
function CloseGuiCommand:_perform_reopen()
  if self.gui_name == "tag_editor" and self.gui_data then
    -- Restore the tag editor with previous data
    Cache.set_tag_editor_data(self.player, self.gui_data)
    return pcall(control_tag_editor.open_tag_editor, self.player)
  elseif self.gui_name == "data_viewer" and self.gui_data then
    -- Add data viewer reopen logic when implemented
    return true
  end
  
  return false
end

--- Check if command can be executed
---@return boolean
function CloseGuiCommand:can_execute()
  return self.player and self.player.valid and not self.executed
end

--- Check if command can be undone
---@return boolean
function CloseGuiCommand:can_undo()
  return self.executed and self.gui_data ~= nil
end

return CloseGuiCommand
