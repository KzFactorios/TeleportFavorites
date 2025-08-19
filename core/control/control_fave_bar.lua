---@diagnostic disable: undefined-global, assign-type-mismatch, param-type-mismatch

-- core/control/control_fave_bar.lua
-- TeleportFavorites Factorio Mod
-- Manages the favorites bar GUI and slot interactions, including drag-and-drop and multiplayer-safe favorites management.

local FavoriteUtils = require("core.favorite.favorite_utils")
local PlayerFavorites = require("core.favorite.player_favorites")
local PlayerHelpers = require("core.utils.player_helpers")
local fave_bar = require("gui.favorites_bar.fave_bar")
local ErrorHandler = require("core.utils.error_handler")
local SlotInteractionHandlers = require("core.control.slot_interaction_handlers")
local GameHelpers = require("core.utils.game_helpers")
local SharedUtils = require("core.control.control_shared_utils")
local CursorUtils = require("core.utils.cursor_utils")
local GuiHelpers = require("core.utils.gui_helpers")
local GuiValidation = require("core.utils.gui_validation")
local Cache = require("core.cache.cache")
local BasicHelpers = require("core.utils.basic_helpers")
local TeleportHistoryModal = require("gui.teleport_history_modal.teleport_history_modal")
local TeleportHistory = require("core.teleport.teleport_history")
local TeleportStrategy = require("core.utils.teleport_strategy")
local Enum = require("prototypes.enums.enum")

local M = {}

-- Runtime state for modal resizing per player
local resize_drag_state = {} -- [player_index] = {dragging=true, start_x, start_y, start_width, start_height}

local function get_mouse_position(event)
  if event and event.cursor_position then
    return event.cursor_position.x, event.cursor_position.y
  end
  return nil, nil
end

--- Reorder favorites using modular handlers
--- Handle individual favorite slot click events
--- This is the main dispatcher for slot interactions, routing different types
--- of clicks to appropriate handlers based on the current state and modifiers.
---@param event table The GUI click event
---@param player LuaPlayer The player
---@param favorites PlayerFavorites The favorites instance
local function handle_favorite_slot_click(event, player, favorites)
  -- Block all slot actions if Ctrl+Alt+Shift+left-click is pressed (delete hotkey)
  if event.button == defines.mouse_button_type.left and event.control and event.alt and event.shift then
    ErrorHandler.debug_log("[FAVE_BAR] Delete hotkey combo detected, blocking slot actions for custom input handler", {
      player = player.name,
      slot = slot
    })
    return
  end
  if not BasicHelpers.is_valid_element(event.element) or not BasicHelpers.is_valid_player(player) then return end
  local slot = tonumber(event.element.name:match("fave_bar_slot_(%d+)"))
  if not slot then
    ErrorHandler.debug_log("[FAVE_BAR] Could not parse slot number from element name", {
      element_name = event.element and event.element.name or "<nil>",
      element_caption = event.element and event.element.caption or "<nil>"
    })
    return
  end

  -- Use shared drag logic
  local is_dragging, source_slot = CursorUtils.is_dragging_favorite(player)
  if is_dragging and source_slot then
    ErrorHandler.debug_log("[FAVE_BAR] Click during drag operation", {
      player = player.name, source_slot = source_slot, target_slot = slot, button_value = event.button
    })
    if event.button == defines.mouse_button_type.right then
      CursorUtils.end_drag_favorite(player)
      GameHelpers.player_print(player, { "tf-gui.fave_bar_drag_canceled" })
      return
    end
    if event.button == defines.mouse_button_type.left then
      if source_slot == slot then
        CursorUtils.end_drag_favorite(player)
        return
      end
      local target_fav = favorites.favorites[slot]
      if target_fav and BasicHelpers.is_locked_favorite(target_fav) then
        GameHelpers.player_print(player, SharedUtils.lstr("tf-gui.fave_bar_locked_cant_target", slot))
        GameHelpers.safe_play_sound(player, { path = "utility/cannot_build" })
        CursorUtils.end_drag_favorite(player)
        return
      end
      if SlotInteractionHandlers.reorder_favorites(player, favorites, source_slot, slot) then return end
    end
    CursorUtils.end_drag_favorite(player)
    return
  end

  local fav = favorites.favorites[slot]
  if not fav then
    ErrorHandler.warn_log("[FAVE_BAR] Slot data missing or nil",
      { slot = slot, player = player and player.name or "<nil>" })
    GameHelpers.player_print(player,
      "[TeleportFavorites] ERROR: Favorite slot data missing. Please refresh your favorites bar.")
    return
  end
  if FavoriteUtils.is_blank_favorite(fav) then return end
  if not fav.gps or type(fav.gps) ~= "string" or fav.gps == "" then
    ErrorHandler.warn_log("[FAVE_BAR] Favorite slot GPS invalid",
      { slot = slot, fav = fav, player = player and player.name or "<nil>" })
    GameHelpers.player_print(player,
      "[TeleportFavorites] ERROR: Favorite slot GPS is invalid. Please update or remove this favorite.")
    return
  end

  -- Use shared slot interaction handlers
  if SlotInteractionHandlers.handle_shift_left_click(event, player, fav, slot, favorites) then return end
  if SlotInteractionHandlers.handle_toggle_lock(event, player, fav, slot, favorites) then return end
  if SlotInteractionHandlers.handle_teleport(event, player, fav, slot, false) then return end

  SlotInteractionHandlers.handle_request_to_open_tag_editor(event, player, fav, slot)
  fave_bar.update_single_slot(player, slot)
end

--- Handle toggle button for favorites bar visibility
---@param event table The GUI click event
---@param player LuaPlayer The player
local function handle_toggle_button_click(event, player)
  -- Only process left clicks for toggling, silently ignore right-clicks
  if event.button ~= defines.mouse_button_type.left then
    return
  end

  -- Use the shared function from fave_bar to get GUI components
  local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
  if not main_flow or not main_flow.valid then return end

  local slots_flow = GuiValidation.find_child_by_name(main_flow, "fave_bar_slots_flow")
  if not slots_flow or not slots_flow.valid then return end

  -- Toggle visibility
  local currently_visible = slots_flow.visible
  local new_visibility = not currently_visible

  -- Update the player data to persist the visibility state
  local player_data = Cache.get_player_data(player)
  player_data.fave_bar_slots_visible = new_visibility

  -- Update the GUI state
  fave_bar.update_toggle_state(player, new_visibility)
end

--- Handle right-click on map during drag operations
---@param event table The GUI click event
---@param player LuaPlayer The player
---@return boolean handled
local function handle_map_right_click(event, player)
  local ok, err = pcall(function()
    if event.button == defines.mouse_button_type.right then
      local is_dragging = CursorUtils.is_dragging_favorite(player)
      if is_dragging then
        ErrorHandler.debug_log("[FAVE_BAR] Right-click detected on map during drag, canceling drag operation",
          { player = player.name })
        CursorUtils.end_drag_favorite(player)
        GameHelpers.player_print(player, { "tf-gui.fave_bar_drag_canceled" })
        return true
      end
    end
    return false
  end)
  if not ok then
    ErrorHandler.warn_log("Error in handle_map_right_click", { error = tostring(err), event = event })
    return false
  end
  return err == true
end

--- Handle favorites bar GUI click events
---@param event table The GUI click event containing element, player_index, button, etc.
local function log_click_event(event, player)
  ErrorHandler.debug_log("[FAVE_BAR] on_fave_bar_gui_click entry point", {
    element_name = event.element.name,
    player = player.name,
    raw_button_value = event.button,
    button_type = event.button == 1 and "LEFT_CLICK" or
        event.button == 2 and "RIGHT_CLICK" or
        event.button == 3 and "MIDDLE_CLICK" or "UNKNOWN_" .. tostring(event.button),
    defines_values = {
      left = defines.mouse_button_type.left,
      right = defines.mouse_button_type.right,
      middle = defines.mouse_button_type.middle
    },
    shift_pressed = event.shift,
    control_pressed = event.control,
    is_dragging = CursorUtils.is_dragging_favorite(player)
  })
end

--- Handle history toggle button click (opens/closes teleport history modal)
---@param event table The GUI click event
---@param player LuaPlayer The player
local function handle_history_toggle_button_click(event, player)
  ErrorHandler.debug_log("[FAVE_BAR] handle_history_toggle_button_click called", {
    event = event,
    player = player and player.name or "<nil>"
  })
  local modal_frame = player.gui.screen[Enum.GuiEnum.GUI_FRAME.TELEPORT_HISTORY_MODAL]
  local modal_open = modal_frame and modal_frame.valid
  if modal_open then
    -- Close the modal
    TeleportHistoryModal.destroy(player)
  else
    TeleportHistoryModal.build(player)
  end
end

--- Handle teleport history modal GUI clicks
---@param event table The GUI click event
local function on_teleport_history_modal_gui_click(event)
  local element = event.element
  local player = game.players[event.player_index]
  if not BasicHelpers.is_valid_element(element) then return end
  if not BasicHelpers.is_valid_player(player) then return end
    
  -- Handle trash can button click for history item deletion
  if element.name and element.name:find("^teleport_history_trash_button_") then
    local index = element.tags and element.tags.teleport_history_index
    ErrorHandler.debug_log("[TELEPORT_HISTORY_MODAL] Trash button click", {
      element_name = element.name,
      tags = element.tags,
      index = index
    })
    if not index or type(index) ~= "number" then
      ErrorHandler.warn_log("Teleport history trash button: index missing or not a number", {
        element_name = element.name, tags = element.tags
      })
      return
    end
    local surface_index = (player.surface and player.surface.valid and player.surface.index) or 1
  local idx = BasicHelpers.normalize_index(index)
  if not idx then return end
  TeleportHistory.remove_history_item(player, surface_index, tostring(idx))
    TeleportHistoryModal.update_history_list(player)
    return
  end

  -- Handle resize handle click (start drag)
  if element.name == "teleport_history_modal_resize_handle" then
    local mouse_x, mouse_y = get_mouse_position(event)
    local modal_frame = player.gui.screen[Enum.GuiEnum.GUI_FRAME.TELEPORT_HISTORY_MODAL]
    if modal_frame and modal_frame.valid and mouse_x and mouse_y then
      local width = modal_frame.style and modal_frame.style.minimal_width or 350
      local height = modal_frame.style and modal_frame.style.minimal_height or 200
      resize_drag_state[player.index] = {
        dragging = true,
        start_x = mouse_x,
        start_y = mouse_y,
        start_width = width,
        start_height = height
      }
      ErrorHandler.debug_log("[MODAL] Resize drag started",
        { player = player.name, x = mouse_x, y = mouse_y, width = width, height = height })
    end
    return
  end

  -- Handle close button
  if element.name == "teleport_history_modal_close_button" then
    TeleportHistoryModal.destroy(player)
    return
  end

  -- Handle history item clicks
  if element.name and element.name:find("^teleport_history_item_") then
    local index = element.tags and element.tags.teleport_history_index
    ErrorHandler.debug_log("[TELEPORT_HISTORY_MODAL] Item click", {
      element_name = element.name,
      tags = element.tags,
      index = index
    })
    if not index or type(index) ~= "number" then
      ErrorHandler.warn_log("Teleport history item click: index missing or not a number",
        { element_name = element.name, tags = element.tags })
      return
    end
    local surface_index = player.surface.index
    local hist = Cache.get_player_teleport_history(player, surface_index)
    ErrorHandler.debug_log("[TELEPORT_HISTORY_MODAL] History stack", {
      surface_index = surface_index,
      hist_stack = hist and hist.stack or nil
    })
    if not hist or not hist.stack then
      ErrorHandler.warn_log("Teleport history item click: history or stack missing",
        { surface_index = surface_index, hist = hist })
      return
    end
    if index < 1 or index > #hist.stack then
      ErrorHandler.warn_log("Teleport history item click: index out of bounds",
        { index = index, stack_length = #hist.stack })
      return
    end
    local stack_entry = hist.stack[index]
    local gps = stack_entry and stack_entry.gps or nil
    ErrorHandler.debug_log("[TELEPORT_HISTORY_MODAL] Stack entry and GPS", {
      stack_entry = stack_entry,
      gps = gps
    })
    if not gps then
      ErrorHandler.warn_log("Teleport history item click: gps missing for index",
        { index = index, stack_entry = stack_entry })
      return
    end

    -- don't add history for a history item click
    local success, err = TeleportStrategy.teleport_to_gps(player, gps, false)
    if success then
      TeleportHistory.set_pointer(player, player.surface.index, index)
      -- Modal stays open after successful teleport from history
    else
      if err and err == "already_at_target" then
        return
      else
        local error_message = tostring(err or "Unknown teleportation failure.")
        ErrorHandler.warn_log("Teleport failed", { gps = gps, error = error_message })
        if player and player.valid then
          ---@type any
          local msg = { "tf-gui.teleport_failed", error_message }
          PlayerHelpers.safe_player_print(player, msg)
        end
      end
    end
  end
end

-- Handle Teleport History confirmation dialog clicks
local function on_history_confirm_dialog_click(event)
  local element = event.element
  local player = game.players[event.player_index]
  if not BasicHelpers.is_valid_element(element) or not BasicHelpers.is_valid_player(player) then return end

  if element.name == Enum.UIEnums.GUI.TeleportHistory.CONFIRM_DIALOG_CONFIRM_BTN then
    -- Clear history for current surface
    local surface_index = player.surface.index
    local hist = Cache.get_player_teleport_history(player, surface_index)
    hist.stack = {}
    hist.pointer = 0
    TeleportHistory.notify_observers(player)
    -- Close dialog and clear modal state
    GuiValidation.safe_destroy_frame(player.gui.screen, Enum.UIEnums.GUI.TeleportHistory.CONFIRM_DIALOG_FRAME)
    Cache.set_modal_dialog_state(player, nil)
    return
  elseif element.name == Enum.UIEnums.GUI.TeleportHistory.CONFIRM_DIALOG_CANCEL_BTN then
    -- Close dialog and clear modal state
    GuiValidation.safe_destroy_frame(player.gui.screen, Enum.UIEnums.GUI.TeleportHistory.CONFIRM_DIALOG_FRAME)
    Cache.set_modal_dialog_state(player, nil)
    return
  end
end

local function on_fave_bar_gui_click(event)
  ErrorHandler.debug_log("[FAVE_BAR] on_fave_bar_gui_click called", {
    element_name = event.element and event.element.name or "<nil>",
    player_index = event.player_index
  })
  local element = event.element
  if not BasicHelpers.is_valid_element(element) then return end
  local player = game.players[event.player_index]
  if not BasicHelpers.is_valid_player(player) then return end
  ---@cast player LuaPlayer

  log_click_event(event, player)

  -- Get player favorites instance
  local favorites = PlayerFavorites.new(player)

  -- Handle right-click on map during drag mode
  if element.name == "map" then
    if handle_map_right_click(event, player) then return end
  end

  if element.name:find("^fave_bar_slot_") then
    handle_favorite_slot_click(event, player, favorites)
    return
  end

  if element.name == "fave_bar_visibility_toggle" then
    handle_toggle_button_click(event, player)
  elseif element.name == "fave_bar_history_toggle" then
    handle_history_toggle_button_click(event, player)
  end
end

M.on_fave_bar_gui_click = on_fave_bar_gui_click
M.on_fave_bar_gui_click_impl = on_fave_bar_gui_click
M.on_teleport_history_modal_gui_click = on_teleport_history_modal_gui_click
M.on_history_confirm_dialog_click = on_history_confirm_dialog_click

return M
