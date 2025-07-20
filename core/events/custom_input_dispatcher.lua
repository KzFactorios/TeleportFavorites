---@diagnostic disable: undefined-global, undefined-field, missing-fields, need-check-nil, param-type-mismatch

-- core/events/custom_input_dispatcher.lua
-- TeleportFavorites Factorio Mod
-- Centralized dispatcher for custom input (keyboard shortcut) events.
-- Features: safe handler registration, error handling, logging, extensible pattern, no global namespace pollution.
-- Usage: register default/custom handlers, all handlers receive Factorio event object.

-- Dependencies
local PlayerHelpers = require("core.utils.player_helpers")
local ErrorHandler = require("core.utils.error_handler")
local PlayerFavorites = require("core.favorite.player_favorites")
local FavoriteUtils = require("core.favorite.favorite_utils")
local Enum = require("prototypes.enums.enum")
local Cache = require("core.cache.cache")
local BasicHelpers = require("core.utils.basic_helpers")
local TeleportStrategy = require("core.utils.teleport_strategy")


---@class CustomInputDispatcher
local M = {}

-- Private helper functions

--- Create a safe wrapper for handler functions with error handling
---@param handler function The handler function to wrap
---@param handler_name string Name for logging purposes
---@return function Safe wrapper function
local function create_safe_handler(handler, handler_name)
  return function(event)
    ErrorHandler.debug_log("Custom input received", {
      handler_name = handler_name,
      player_index = event.player_index,
      input_name = event.input_name
    })
    
    -- Block custom inputs when modal dialogs are active (except ESC key equivalents)
    if event.player_index then
      local player = game.get_player(event.player_index)
      if BasicHelpers.is_valid_player(player) and Cache.is_modal_dialog_active(player) then
        -- Allow certain inputs that should work in modals (like ESC key)
        local allowed_inputs = {
          "tf-close-tag-editor",  -- Allow closing tag editor
          "tf-close-modal"        -- Allow generic modal close
        }
        
        local input_allowed = false
        for _, allowed_input in ipairs(allowed_inputs) do
          if event.input_name == allowed_input then
            input_allowed = true
            break
          end
        end
        
        if not input_allowed then
          ErrorHandler.debug_log("[MODAL BLOCKER] Blocking custom input", {
            input_name = event.input_name,
            player_index = event.player_index,
            modal_type = Cache.get_modal_dialog_type(player)
          })
          return -- Block the input
        end
      end
    end
    
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
          PlayerHelpers.error_message_to_player(player, "Input handler error occurred")
        end
      end
    end
  end
end

--- Helper function to handle teleporting to a favorite slot
---@param event table The custom input event
---@param slot_number number The favorite slot number (1-10)
local function handle_teleport_to_favorite_slot(event, slot_number)
  local player = game.get_player(event.player_index)
  if not player or not player.valid then 
    ErrorHandler.debug_log("Invalid player in teleport handler", { player_index = event.player_index })
    return 
  end

  -- Early exit if favorites are disabled
  local player_settings = Cache.Settings.get_player_settings(player)
  if not player_settings.favorites_on then
    return
  end

  local player_favorites = PlayerFavorites.new(player)
  if not player_favorites or not player_favorites.favorites then
    PlayerHelpers.safe_player_print(player, {"tf-gui.no_favorites_available"})
    return
  end
  
  -- Get the favorite at the specified slot
  local favorite = player_favorites.favorites[slot_number]
  if not favorite or FavoriteUtils.is_blank_favorite(favorite) then
    ErrorHandler.debug_log("Favorite slot empty", { player = player.name, slot = slot_number })
    PlayerHelpers.safe_player_print(player, {"tf-gui.favorite_slot_empty"})
    return
  end
  
  -- Use Tag module for teleportation (already has all the strategy logic)
  local result = TeleportStrategy.teleport_to_gps(player, favorite.gps)
  local success = result == Enum.ReturnStateEnum.SUCCESS
  
  ErrorHandler.debug_log("Teleport to favorite slot result", {
    player = player.name,
    slot = slot_number,
    gps = favorite.gps,
    result = result,
    success = success
  })
end

local default_custom_input_handlers = {
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
}

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

return M
