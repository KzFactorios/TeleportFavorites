---@diagnostic disable: undefined-global, undefined-field, missing-fields, need-check-nil, param-type-mismatch

-- core/events/custom_input_dispatcher.lua
-- TeleportFavorites Factorio Mod
-- Centralized dispatcher for custom input (keyboard shortcut) events.
-- Features: safe handler registration, error handling, logging, extensible pattern, no global namespace pollution.
-- Usage: register default/custom handlers, all handlers receive Factorio event object.

local PlayerHelpers = require("core.utils.player_helpers")
local ErrorHandler = require("core.utils.error_handler")
local FavoriteUtils = require("core.favorite.favorite_utils")
local Enum = require("prototypes.enums.enum")
local Cache = require("core.cache.cache")
local BasicHelpers = require("core.utils.basic_helpers")
local TeleportStrategy = require("core.utils.teleport_strategy")
local TeleportHistory = require("core.teleport.teleport_history")


local M = {}


-- Helper function to handle teleporting to a favorite slot
local function handle_teleport_to_favorite_slot(event, slot_number)
  local player = game.get_player(event.player_index)
  if not player or not player.valid then
    ErrorHandler.debug_log("Invalid player in teleport handler", { player_index = event.player_index })
    return
  end

  -- Early exit if favorites are disabled
  local player_settings = Cache.Settings.get_player_settings(player)
  if not player_settings.favorites_on then
    ErrorHandler.debug_log("Favorites are disabled in player settings", { player = player.name })
    return
  end

  local surface_index = player.surface.index
  local favorites = Cache.get_player_favorites(player, surface_index)
  ErrorHandler.debug_log("Fetched favorites for surface", {
    player = player.name,
    surface_index = surface_index,
    favorites_count = favorites and #favorites or 0,
    favorites = favorites
  })
  if not favorites then
    PlayerHelpers.safe_player_print(player, "tf-gui.no_favorites_available")
    ErrorHandler.debug_log("No favorites available for player", { player = player.name, surface_index = surface_index })
    return
  end
  -- Get the favorite at the specified slot
  local favorite = favorites[slot_number]
  ErrorHandler.debug_log("Favorite slot data", {
    player = player.name,
    slot = slot_number,
    favorite = favorite
  })
  if not favorite or FavoriteUtils.is_blank_favorite(favorite) then
    ErrorHandler.debug_log("Favorite slot empty or blank",
      { player = player.name, slot = slot_number, favorite = favorite })
    PlayerHelpers.safe_player_print(player, "tf-gui.favorite_slot_empty")
    return
  end

  -- Use Tag module for teleportation (already has all the strategy logic)
  ErrorHandler.debug_log("Attempting teleport to GPS", {
    player = player.name,
    slot = slot_number,
    gps = favorite.gps,
    favorite = favorite
  })
  local result = TeleportStrategy.teleport_to_gps(player, favorite.gps)
  local success = result == Enum.ReturnStateEnum.SUCCESS

  ErrorHandler.debug_log("Teleport to favorite slot result", {
    player = player.name,
    slot = slot_number,
    gps = favorite.gps,
    result = result,
    success = success,
    favorite = favorite
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
  ["teleport_history-prev"] = function(event)
    local player = game.get_player(event.player_index)
    if player and player.valid then
      local surface_index = player.surface.index
      local hist = Cache.get_player_teleport_history(player, surface_index)
      if hist and hist.stack and #hist.stack > 0 then
        local new_pointer = math.max(1, hist.pointer - 1)
        TeleportHistory.set_pointer(player, surface_index, new_pointer)
        local pointer = math.max(1, math.min(hist.pointer, #hist.stack))
        local entry = hist.stack[pointer]
        if entry and type(entry) == "table" and entry.gps then
          TeleportStrategy.teleport_to_gps(player, entry.gps, false)
        else
          ErrorHandler.debug_log("History navigation: invalid entry or empty stack", {
            pointer = pointer,
            stack_size = #hist.stack,
            entry_type = type(entry),
            entry_gps = entry and entry.gps or nil
          })
        end
      end
    end
  end,
  ["teleport_history-next"] = function(event)
    local player = game.get_player(event.player_index)
    if player and player.valid then
      local surface_index = player.surface.index
      local hist = Cache.get_player_teleport_history(player, surface_index)
      if hist and hist.stack and #hist.stack > 0 then
        local new_pointer = math.min(#hist.stack, hist.pointer + 1)
        TeleportHistory.set_pointer(player, surface_index, new_pointer)
        local pointer = math.max(1, math.min(hist.pointer, #hist.stack))
        local entry = hist.stack[pointer]
        if entry and type(entry) == "table" and entry.gps then
          TeleportStrategy.teleport_to_gps(player, entry.gps, false)
        else
          ErrorHandler.debug_log("History navigation: invalid entry or empty stack", {
            pointer = pointer,
            stack_size = #hist.stack,
            entry_type = type(entry),
            entry_gps = entry and entry.gps or nil
          })
        end
      end
    end
  end,
  ["teleport_history-first"] = function(event)
    local player = game.get_player(event.player_index)
    if player and player.valid then
      local surface_index = player.surface.index
      local hist = Cache.get_player_teleport_history(player, surface_index)
      if hist and hist.stack and #hist.stack > 0 then
        TeleportHistory.set_pointer(player, surface_index, 1)
        local pointer = math.max(1, math.min(hist.pointer, #hist.stack))
        local entry = hist.stack[pointer]
        if entry and type(entry) == "table" and entry.gps then
          TeleportStrategy.teleport_to_gps(player, entry.gps, false)
        else
          ErrorHandler.debug_log("History navigation: invalid entry or empty stack", {
            pointer = pointer,
            stack_size = #hist.stack,
            entry_type = type(entry),
            entry_gps = entry and entry.gps or nil
          })
        end
      end
    end
  end,
  ["teleport_history-last"] = function(event)
    local player = game.get_player(event.player_index)
    if player and player.valid then
      local surface_index = player.surface.index
      local hist = Cache.get_player_teleport_history(player, surface_index)
      if hist and hist.stack and #hist.stack > 0 then
        TeleportHistory.set_pointer(player, surface_index, #hist.stack)
        local pointer = math.max(1, math.min(hist.pointer, #hist.stack))
        local entry = hist.stack[pointer]
        if entry and type(entry) == "table" and entry.gps then
          TeleportStrategy.teleport_to_gps(player, entry.gps, false)
        else
          ErrorHandler.debug_log("History navigation: invalid entry or empty stack", {
            pointer = pointer,
            stack_size = #hist.stack,
            entry_type = type(entry),
            entry_gps = entry and entry.gps or nil
          })
        end
      end
    end
  end,
  ["teleport_history-clear"] = function(event)
    local player = game.get_player(event.player_index)
    if player and player.valid then
      local surface_index = player.surface.index
      local hist = Cache.get_player_teleport_history(player, surface_index)
      hist.stack = {}
      hist.pointer = 0
      TeleportHistory.notify_observers(player)
      -- Modal will auto-update via observer
    end
  end,
}

--- Create a safe wrapper for handler functions with error handling
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
          "tf-close-tag-editor", -- Allow closing tag editor
          "tf-close-modal"       -- Allow generic modal close
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
          return   -- Block the input
        end
      end
    end

    local success, err = pcall(handler, event)
    if not success then
      ErrorHandler.warn_log("Custom input handler failed", {
        error = tostring(err),
        player_index = event.player_index
      })
      -- Could also show player message for user-facing errors
      if event.player_index then
        local player = game.get_player(event.player_index)
        if player and player.valid then
          PlayerHelpers.error_message_to_player(player, "Input handler error occurred")
        end
      end
    end
  end
end

--- Register all default custom input handlers with Factorio's event system
---@param script table The Factorio script object
function M.register_default_inputs(script)
  if not script or type(script.on_event) ~= "function" then
    ErrorHandler.warn_log("Invalid script object for custom input registration")
    return false
  end
  ErrorHandler.debug_log("Registering default custom input handlers")
  ErrorHandler.debug_log("Handler table keys:",
    { keys = (default_custom_input_handlers and table.concat((function()
      local t = {}
      for k, _ in pairs(default_custom_input_handlers) do table.insert(t, k) end
      return t
    end)(), ", ") or "nil") })
  local count = 0
  for input_name, handler in pairs(default_custom_input_handlers) do
    local safe_handler = create_safe_handler(handler, input_name)
    local success, err = pcall(function()
      script.on_event(input_name, safe_handler)
    end)
    if success then
      count = count + 1
      ErrorHandler.debug_log("Registered custom input handler", { input_name = input_name })
    else
      ErrorHandler.warn_log("Failed to register custom input handler", { input_name = input_name, error = err })
    end
  end
  ErrorHandler.debug_log("Custom input handler registration complete", { registered = count })
  return true
end

M.default_custom_input_handlers = default_custom_input_handlers

return M
