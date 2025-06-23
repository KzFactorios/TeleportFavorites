---@diagnostic disable: undefined-global, undefined-field, missing-fields, need-check-nil, param-type-mismatch
--[[
custom_input_dispatcher.lua
TeleportFavorites Factorio Mod
-----------------------------
Centralized dispatcher for custom input (keyboard shortcut) events.

Features:
---------
- Safe handler registration with comprehensive validation
- Error handling and recovery for individual handlers
- Proper logging for debugging and monitoring
- Extensible pattern for adding new custom inputs
- No global namespace pollution

Usage:
------
-- Register default handlers
CustomInputDispatcher.register_default_inputs(script)

-- Register custom handlers
CustomInputDispatcher.register_custom_inputs(script, {
  ["my-custom-input"] = function(event) ... end
})

Handler Signature:
------------------
All handlers receive a Factorio event object:
function handler(event)
  -- event.player_index: uint - Player who triggered the input
  -- event.input_name: string - Name of the custom input
  -- event.cursor_position: MapPosition - Cursor position when triggered
end
--]]

-- Dependencies
local control_data_viewer = require("core.control.control_data_viewer")
local on_gui_closed_handler = require("core.events.on_gui_closed_handler")
local handlers = require("core.events.handlers")
local GameHelpers = require("core.utils.game_helpers")
local ErrorHandler = require("core.utils.error_handler")
local PlayerFavorites = require("core.favorite.player_favorites")
local FavoriteUtils = require("core.favorite.favorite")
local Enum = require("prototypes.enums.enum")
local GPSUtils = require("core.utils.gps_utils")


---@class CustomInputDispatcher
local M = {}

-- Private helper functions

--- Create a safe wrapper for handler functions with error handling
---@param handler function The handler function to wrap
---@param handler_name string Name for logging purposes
---@return function Safe wrapper function
local function create_safe_handler(handler, handler_name)
  return function(event)
    local success, err = pcall(handler, event)
    if not success then
      ErrorHandler.warn_log("Custom input handler failed", {
        handler_name = handler_name,
        error = tostring(err),
        player_index = event.player_index 
      })
      -- Could also show player message for user-facing errors
      if event.player_index then
        ---@diagnostic disable-next-line: undefined-field
        local player = game.get_player(event.player_index)
        ---@diagnostic disable-next-line: need-check-nil
        if player and player.valid then
          ---@diagnostic disable-next-line: param-type-mismatch
          GameHelpers.player_print(player, {"tf-error.input_handler_error"})
        end
      end
    end
  end
end

-- Default custom input handlers (private to avoid global pollution)
---@type table<string, function>

--- Helper function to handle teleporting to a favorite slot
---@param event table The custom input event
---@param slot_number number The favorite slot number (1-10)
local function handle_teleport_to_favorite_slot(event, slot_number)
  local player = game.get_player(event.player_index)
  if not player or not player.valid then return end
  
  -- Use the shared teleportation utility
  local success = GameHelpers.teleport_to_favorite_slot(player, slot_number)
  
  ErrorHandler.debug_log("Teleport to favorite slot via hotkey", {
    player = player.name,
    slot = slot_number,
    success = success
  })
end

local default_custom_input_handlers = {
  ["dv-toggle-data-viewer"] = control_data_viewer.on_toggle_data_viewer,
  ["tf-undo-last-action"] = function(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    
    -- Use the GUI handler's undo function
    local success = on_gui_closed_handler.undo_last_gui_close(player)
    
    if success then
      GameHelpers.player_print(player, {"tf-command.action_undone"})
    else
      GameHelpers.player_print(player, {"tf-command.nothing_to_undo"})
    end
  end,
  -- Teleport to favorite slot handlers (Ctrl+1 through Ctrl+0)
  [Enum.EventEnum.TELEPORT_TO_FAVORITE .. "1"] = function(event) handle_teleport_to_favorite_slot(event, 1) end,
  [Enum.EventEnum.TELEPORT_TO_FAVORITE .. "2"] = function(event) handle_teleport_to_favorite_slot(event, 2) end,
  [Enum.EventEnum.TELEPORT_TO_FAVORITE .. "3"] = function(event) handle_teleport_to_favorite_slot(event, 3) end,
  [Enum.EventEnum.TELEPORT_TO_FAVORITE .. "4"] = function(event) handle_teleport_to_favorite_slot(event, 4) end,
  [Enum.EventEnum.TELEPORT_TO_FAVORITE .. "5"] = function(event) handle_teleport_to_favorite_slot(event, 5) end,
  [Enum.EventEnum.TELEPORT_TO_FAVORITE .. "6"] = function(event) handle_teleport_to_favorite_slot(event, 6) end,
  [Enum.EventEnum.TELEPORT_TO_FAVORITE .. "7"] = function(event) handle_teleport_to_favorite_slot(event, 7) end,
  [Enum.EventEnum.TELEPORT_TO_FAVORITE .. "8"] = function(event) handle_teleport_to_favorite_slot(event, 8) end,
  [Enum.EventEnum.TELEPORT_TO_FAVORITE .. "9"] = function(event) handle_teleport_to_favorite_slot(event, 9) end,
  [Enum.EventEnum.TELEPORT_TO_FAVORITE .. "10"] = function(event) handle_teleport_to_favorite_slot(event, 10) end,
  -- Add more custom input handlers here as needed
}

-- Public API

--- Register custom input handlers with comprehensive validation
---@param script table The Factorio script object
---@param handlers table<string, function> Table mapping input names to handler functions
---@return boolean success Whether registration completed successfully
function M.register_custom_inputs(script, handlers)
  -- Validate script object
  if not script or type(script.on_event) ~= "function" then
    error("[TeleportFavorites] Invalid script object provided to register_custom_inputs")
  end
  
  -- Validate handlers table
  if not handlers or type(handlers) ~= "table" then
    error("[TeleportFavorites] Handlers must be a table")
  end
  
  local registration_count = 0
  local error_count = 0
    -- Register each handler with validation
  for input_name, handler in pairs(handlers) do
    if type(input_name) ~= "string" or input_name == "" then
      ErrorHandler.warn_log("Invalid custom input name", {
        input_name = tostring(input_name)
      })
      error_count = error_count + 1
    elseif type(handler) ~= "function" then
      ErrorHandler.warn_log("Invalid custom input handler", {
        input_name = input_name,
        handler_type = type(handler)
      })
      error_count = error_count + 1
    else
      -- Wrap handler in safety wrapper and register
      local safe_handler = create_safe_handler(handler, input_name)
      local success, err = pcall(function()
        script.on_event(input_name, safe_handler)
      end)
        if success then
        registration_count = registration_count + 1
        ErrorHandler.debug_log("Registered custom input", {
          input_name = input_name
        })
      else
        ErrorHandler.warn_log("Failed to register custom input", {
          input_name = input_name,
          error = tostring(err)
        })
        error_count = error_count + 1
      end
    end  end
  
  ErrorHandler.debug_log("Custom input registration complete", {
    registered_count = registration_count,
    error_count = error_count
  })
  return error_count == 0
end

--- Register the default TeleportFavorites custom input handlers
---@param script table The Factorio script object
---@return boolean success Whether registration completed successfully
function M.register_default_inputs(script)
  ErrorHandler.debug_log("Registering default custom inputs")
  return M.register_custom_inputs(script, default_custom_input_handlers)
end

--- Get a copy of the default handlers (for testing or extension)
---@return table<string, function> Copy of default handlers
function M.get_default_handlers()
  local copy = {}
  for name, handler in pairs(default_custom_input_handlers) do
    copy[name] = handler
  end
  return copy
end

return M
