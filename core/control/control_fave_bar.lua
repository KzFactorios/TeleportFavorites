---@diagnostic disable: undefined-global, assign-type-mismatch, param-type-mismatch

-- control_fave_bar.lua
-- Handles favorites bar GUI events for TeleportFavorites
-- 
-- This module serves as the main coordinator for favorites bar interactions,
-- dispatching different types of user interactions to specialized handlers.
-- Key functionality includes:
-- - Drag and drop reordering of favorites
-- - Teleportation to favorite locations  
-- - Lock/unlock toggle for favorites
-- - Tag editor integration
-- - Visibility controls
--
-- Architecture: Uses modular handlers in SlotInteractionHandlers and DragDropUtils
-- for better maintainability and separation of concerns.

local PlayerFavorites = require("core.favorite.player_favorites")
local FavoriteUtils = require("core.favorite.favorite")
local SmallHelpers = require("core.utils.small_helpers")
local fave_bar = require("gui.favorites_bar.fave_bar")
local ErrorHandler = require("core.utils.error_handler")
local SlotInteractionHandlers = require("core.control.slot_interaction_handlers")
local GameHelpers = require("core.utils.game_helpers")
local SharedUtils = require("core.control.control_shared_utils")
local CursorUtils = require("core.utils.cursor_utils")
local GuiHelpers = require("core.utils.gui_helpers")
local GuiValidation = require("core.utils.gui_validation")
local Cache = require("core.cache.cache")

local M = {}

--- Reorder favorites using modular handlers
---@param player LuaPlayer The player
---@param favorites PlayerFavorites The favorites instance
---@param drag_index number The source slot index
---@param slot number The target slot index
---@return boolean success
local function reorder_favorites(player, favorites, drag_index, slot)
  -- Custom drag algorithm: if destination is blank, swap and do not cascade
  local favs = favorites.favorites
  if not favs or not favs[drag_index] or not favs[slot] then return false end
  local src_fav = favs[drag_index]
  local dst_fav = favs[slot]
  if FavoriteUtils.is_blank_favorite(dst_fav) then
    -- Swap source and destination
    favs[slot] = src_fav
    favs[drag_index] = FavoriteUtils.get_blank_favorite()
    favorites.favorites = favs
    -- Removed player print for blank slot swap per user request
    -- Rebuild bar and end drag
    fave_bar.build(player)
    CursorUtils.end_drag_favorite(player)
    return true
  end
  -- Fallback to default cascade logic
  return SlotInteractionHandlers.reorder_favorites(player, favorites, drag_index, slot)
end

--- Handle teleport operation
---@param event table The GUI event
---@param player LuaPlayer The player
---@param fav table The favorite
---@param slot number The slot number
---@param did_drag boolean Whether this was part of a drag operation
---@return boolean handled
local function handle_teleport(event, player, fav, slot, did_drag)
  return SlotInteractionHandlers.handle_teleport(event, player, fav, slot, did_drag)
end

--- Handle request to open tag editor
---@param event table The GUI event
---@param player LuaPlayer The player
---@param fav table The favorite
---@param slot number The slot number
---@return boolean handled
local function handle_request_to_open_tag_editor(event, player, fav, slot)
  return SlotInteractionHandlers.handle_request_to_open_tag_editor(event, player, fav, slot)
end

--- Handle toggle lock operation
---@param event table The GUI event
---@param player LuaPlayer The player
---@param fav table The favorite
---@param slot number The slot number
---@param favorites PlayerFavorites The favorites instance
---@return boolean handled
local function handle_toggle_lock(event, player, fav, slot, favorites)
  return SlotInteractionHandlers.handle_toggle_lock(event, player, fav, slot, favorites)
end

--- Handle shift+left click to start drag
---@param event table The GUI event
---@param player LuaPlayer The player
---@param fav table The favorite
---@param slot number The slot number
---@param favorites PlayerFavorites The favorites instance
---@return boolean handled
local function handle_shift_left_click(event, player, fav, slot, favorites)
  return SlotInteractionHandlers.handle_shift_left_click(event, player, fav, slot, favorites)
end

--- Handle drop on slot operation
---@param event table The GUI event
---@param player LuaPlayer The player
---@param slot number The target slot number
---@param favorites PlayerFavorites The favorites instance
---@return boolean handled
local function handle_drop_on_slot(event, player, slot, favorites)
  return SlotInteractionHandlers.handle_drop_on_slot(event, player, slot, favorites)
end

--- Handle individual favorite slot click events
--- This is the main dispatcher for slot interactions, routing different types
--- of clicks to appropriate handlers based on the current state and modifiers.
---@param event table The GUI click event
---@param player LuaPlayer The player
---@param favorites PlayerFavorites The favorites instance
local function handle_favorite_slot_click(event, player, favorites)
  local element = event.element
  local slot = tonumber(element.name:match("fave_bar_slot_(%d+)"))
  if not slot then
    ErrorHandler.debug_log("[FAVE_BAR] Could not parse slot number from element name", {
      element_name = element and element.name or "<nil>",
      element_caption = element and element.caption or "<nil>"
    })
    return
  end
    -- Log more detailed information about the click event
  ErrorHandler.debug_log("[FAVE_BAR] Slot click detected", {
    player = player and player.name or "<nil>",
    slot = slot,
    button_value = event and event.button or "<nil>",
    button_type = event and event.button and (
      event.button == 1 and "LEFT_CLICK" or
      event.button == 2 and "RIGHT_CLICK" or
      event.button == 3 and "MIDDLE_CLICK" or
      "UNKNOWN_BUTTON_" .. tostring(event.button)
    ) or "<nil>",
    shift = event and event.shift or false,
    control = event and event.control or false
  })
  
  -- PRIORITY CHECK: First check if we're in drag mode and this is a drop or cancel
  local is_dragging, source_slot = CursorUtils.is_dragging_favorite(player)
  
  -- Enhanced drag detection logging
  if is_dragging then
    ErrorHandler.debug_log("[FAVE_BAR] In active drag mode", {
      player = player.name,
      source_slot = source_slot,
      target_slot = slot
    })
  end
  
  if is_dragging then
    ErrorHandler.debug_log("[FAVE_BAR] Click during drag operation", {
      player = player.name,
      source_slot = source_slot,
      target_slot = slot,
      button_value = event.button,
      raw_button = event.button
    })
      -- Check if this is a right-click to cancel the drag
    if event.button == defines.mouse_button_type.right then
      ErrorHandler.debug_log("[FAVE_BAR] Right-click detected during drag, canceling drag operation", 
        { player = player.name, source_slot = source_slot })
      CursorUtils.end_drag_favorite(player)
      GameHelpers.player_print(player, {"tf-gui.fave_bar_drag_canceled"})
      return
    end
      -- Check if this is a left-click to complete the drag
    if event.button == defines.mouse_button_type.left then
      ErrorHandler.debug_log("[FAVE_BAR] Left-click detected during drag, attempting to drop", 
        { player = player.name, source_slot = source_slot, target_slot = slot, raw_button = event.button })
      
      -- Direct attempt to reorder favorites (skip handle_drop_on_slot)
      if source_slot ~= slot then
        local target_fav = favorites.favorites[slot]
        
        -- Check if target slot is locked
        if target_fav and SmallHelpers.is_locked_favorite(target_fav) then
          GameHelpers.player_print(player, SharedUtils.lstr("tf-gui.fave_bar_locked_cant_target", slot))
          GameHelpers.safe_play_sound(player, { path = "utility/cannot_build" })
          CursorUtils.end_drag_favorite(player)
          ErrorHandler.debug_log("[FAVE_BAR] Target slot is locked, canceling drag")
          return
        end
        
        -- Target slot is not locked, proceed with reordering
        ErrorHandler.debug_log("[FAVE_BAR] Directly reordering favorites", {
          from_slot = source_slot,
          to_slot = slot
        })
        
        if source_slot and slot then
          local success = reorder_favorites(player, favorites, source_slot, slot)
          if success then
            ErrorHandler.debug_log("[FAVE_BAR] Drop successful via direct reordering")
            return
          else
            ErrorHandler.debug_log("[FAVE_BAR] Direct reordering failed")
          end
        end
      else
        -- Dropping onto the same slot, just end the drag
        ErrorHandler.debug_log("[FAVE_BAR] Dropping onto same slot, canceling drag", {
          slot = slot
        })
        CursorUtils.end_drag_favorite(player)
        return
      end
      
      -- Fallback to regular drop handler
      ErrorHandler.debug_log("[FAVE_BAR] Falling back to regular drop handler")
      if handle_drop_on_slot(event, player, slot, favorites) then
        ErrorHandler.debug_log("[FAVE_BAR] Drop successful via fallback handler")
        return
      end
      
      -- If we get here, all drop attempts failed
      ErrorHandler.debug_log("[FAVE_BAR] Drop unsuccessful after all attempts, ending drag anyway")
    end
    
    -- If we get here, the drop didn't work or it was another button, but we need to exit drag mode anyway
    CursorUtils.end_drag_favorite(player)
    return
  end
  
  -- Not in drag mode, proceed with normal handling
  local fav = favorites.favorites[slot]
  if fav == nil then return end
  
  -- Check for blank favorite (different handling)
  if FavoriteUtils.is_blank_favorite(fav) then
    -- For blank favorites, only allow drag targets (no teleport/etc)
    return
  end

  -- Handle Shift+Left-Click to start drag
  if SlotInteractionHandlers.handle_shift_left_click(event, player, fav, slot, favorites) then return end

  -- Handle Ctrl+click to toggle lock state
  if SlotInteractionHandlers.handle_toggle_lock(event, player, fav, slot, favorites) then return end

  -- Normal left-click to teleport
  if SlotInteractionHandlers.handle_teleport(event, player, fav, slot, false) then return end

  -- Right-click to open tag editor
  SlotInteractionHandlers.handle_request_to_open_tag_editor(event, player, fav, slot)

  -- Use partial update for single slot changes where possible
  -- Only rebuild entire slot row if the slot structure has fundamentally changed
  -- Most slot interactions just need individual slot updates
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
  
  local bar_frame = GuiValidation.find_child_by_name(main_flow, "fave_bar_frame")
  if not bar_frame or not bar_frame.valid then return end
  
  local bar_flow = GuiValidation.find_child_by_name(bar_frame, "fave_bar_flow")
  if not bar_flow or not bar_flow.valid then return end
  
  local slots_flow = GuiValidation.find_child_by_name(bar_flow, "fave_bar_slots_flow")
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
  if event.button == defines.mouse_button_type.right then
    local is_dragging = CursorUtils.is_dragging_favorite(player)
    if is_dragging then
      ErrorHandler.debug_log("[FAVE_BAR] Right-click detected on map during drag, canceling drag operation", { player = player.name })
      CursorUtils.end_drag_favorite(player)
      GameHelpers.player_print(player, {"tf-gui.fave_bar_drag_canceled"})
      return true
    end
  end
  return false
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

local function on_fave_bar_gui_click(event)
  local element = event.element
  if not element or not element.valid then return end
  local player = game.get_player(event.player_index)
  if not player or not player.valid then return end

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
  end
end

M.on_fave_bar_gui_click = on_fave_bar_gui_click
M.on_fave_bar_gui_click_impl = on_fave_bar_gui_click

return M
