---@diagnostic disable: undefined-global, assign-type-mismatch, param-type-mismatch

-- control_fave_bar.lua
-- Handles favorites bar GUI events for TeleportFavorites

local PlayerFavorites = require("core.favorite.player_favorites")
local FavoriteUtils = require("core.favorite.favorite")
local fave_bar = require("gui.favorites_bar.fave_bar")
local Cache = require("core.cache.cache")
local tag_editor = require("gui.tag_editor.tag_editor")
local gps_core = require("core.utils.gps_utils")
local GameHelpers = require("core.utils.game_helpers")
local GuiUtils = require("core.utils.gui_utils")
local ErrorHandler = require("core.utils.error_handler")
local LocaleUtils = require("core.utils.locale_utils")
local FavoriteRuntimeUtils = require("core.utils.favorite_utils")

-- Observer Pattern Integration
local GuiObserver = require("core.pattern.gui_observer")
local GuiEventBus = GuiObserver.GuiEventBus

local M = {}

local function lstr(key, ...)
  return { key, ... }
end

local CursorUtils = require("core.utils.cursor_utils")

local function is_locked_favorite(fav)
  -- Defensive: treat nil as not locked
  return fav and fav.locked == true
end

local function start_drag(player, fav, slot)
  -- Start dragging using cursor utils
  local success = CursorUtils.start_drag_favorite(player, fav, slot)
  -- No need for user feedback here - it's handled in CursorUtils.start_drag_favorite
  return success
end

local function end_drag(player)
  -- End dragging using cursor utils
  return CursorUtils.end_drag_favorite(player)
end

local function reorder_favorites(player, favorites, drag_index, slot)
  -- Use PlayerFavorites move_favorite method instead of manual array manipulation  
  local success, error_msg = favorites:move_favorite(drag_index, slot)
  if not success then
    GameHelpers.player_print(player, LocaleUtils.get_error_string(player, "failed_reorder_favorite", {error_msg or LocaleUtils.get_error_string(player, "unknown_error")}))
    end_drag(player)
    return false
  end

  -- Rebuild the entire favorites bar to reflect new order
  fave_bar.build(player)
  GameHelpers.player_print(player, lstr("tf-gui.fave_bar_reordered", drag_index, slot))
  end_drag(player)
  return true
end

local function open_tag_editor_from_favorite(player, favorite)
  local tag_data = {}

  if favorite then
    -- Rehydrate the favorite to ensure all runtime fields are present
    favorite = FavoriteRuntimeUtils.rehydrate_favorite(player, favorite)
    -- Create initial tag data from favorite
    local tag_data = Cache.create_tag_editor_data({
      gps = favorite.gps,
      locked = favorite.locked,
      is_favorite = true,  -- Always true when opening from favorites bar
      icon = favorite.tag.chart_tag.icon or "",
      text = favorite.tag.chart_tag.text or "",
      tag = favorite.tag,
      chart_tag = favorite.chart_tag
    })

    -- Persist gps in tag_editor_data
    Cache.set_tag_editor_data(player, tag_data)
    tag_editor.build(player)
  end
end

local function can_start_drag(fav)
  return fav and not FavoriteUtils.is_blank_favorite(fav) and not is_locked_favorite(fav)
end

local function handle_drag_start(event, player, fav, slot)
  if event.button == defines.mouse_button_type.left and not event.control and can_start_drag(fav) then
    start_drag(player, fav, slot)
    return true
  end
  return false
end

local function handle_reorder(event, player, favorites, drag_index, slot)
  if event.button == defines.mouse_button_type.left and not event.control and drag_index and drag_index ~= slot then
    return reorder_favorites(player, favorites, drag_index, slot)
  elseif event.button == defines.mouse_button_type.left and not event.control and drag_index and drag_index == slot then
    end_drag(player)
    return true
  end
  return false
end

local function handle_teleport(event, player, fav, slot, did_drag)
  if event.button == defines.mouse_button_type.left and not event.control and not did_drag then
    if fav and not FavoriteUtils.is_blank_favorite(fav) then
      GameHelpers.safe_teleport(player, gps_core.map_position_from_gps(fav.gps))
      return true
    end
  end
  return false
end

local function handle_request_to_open_tag_editor(event, player, fav, slot)
  if event.button == defines.mouse_button_type.right then
    -- Check if player is currently in a drag operation
    local is_dragging, _ = CursorUtils.is_dragging_favorite(player)
    if is_dragging then
      -- Don't open tag editor during drag operations
      return false
    end
    
    if fav and not FavoriteUtils.is_blank_favorite(fav) then
      -- removed extra gps argument
      open_tag_editor_from_favorite(player, fav)
      return true
    end
  end
  return false
end

local function handle_toggle_lock(event, player, fav, slot, favorites)
  if event.button == defines.mouse_button_type.left and event.control then    
    local success, error_msg = favorites:toggle_favorite_lock(slot)
    if not success then
      GameHelpers.player_print(player, LocaleUtils.get_error_string(player, "failed_toggle_lock", 
        {error_msg or LocaleUtils.get_error_string(player, "unknown_error")}))
      return false
    end-- Update the slot row to reflect lock state change
    local main_flow = GuiUtils.get_or_create_gui_flow_from_gui_top(player)
    local bar_frame = GuiUtils.find_child_by_name(main_flow, "fave_bar_frame")
    local bar_flow = bar_frame and GuiUtils.find_child_by_name(bar_frame, "fave_bar_flow")
    if bar_flow then
      fave_bar.update_slot_row(player, bar_flow)
    end
    
    local lock_state = fav.locked and "locked" or "unlocked"
    GameHelpers.player_print(player, lstr("tf-gui.fave_bar_lock_toggled", slot, lock_state))
    return true
  end
  return false
end

local function handle_shift_left_click(event, player, fav, slot, favorites)
  if event.button == defines.mouse_button_type.left and event.shift then
    -- Check if we can start a drag (not a blank or locked favorite)
    if can_start_drag(fav) then
      start_drag(player, fav, slot)
      return true
    elseif is_locked_favorite(fav) then
      GameHelpers.player_print(player, lstr("tf-gui.fave_bar_locked_cant_drag", slot))
    end
  end
  return false
end

local function handle_drop_on_slot(event, player, slot, favorites)
  -- Check if player is currently dragging a favorite
  local is_dragging, source_slot = CursorUtils.is_dragging_favorite(player)
  if is_dragging and source_slot and source_slot ~= slot then
    -- Make sure target slot isn't locked
    local target_fav = favorites.favorites[slot]
    if target_fav and not is_locked_favorite(target_fav) then
      return reorder_favorites(player, favorites, source_slot, slot)
    elseif is_locked_favorite(target_fav) then
      GameHelpers.player_print(player, lstr("tf-gui.fave_bar_locked_cant_target", slot))
      GameHelpers.safe_play_sound(player, { path = "utility/cannot_build" })
      end_drag(player)
      return true
    end
  end
  return false
end

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
    -- First check if we're in drag mode and this is a drop or cancel
  local is_dragging, source_slot = CursorUtils.is_dragging_favorite(player)
  if is_dragging then
    -- Check if this is a right-click to cancel the drag
    if event.button == defines.mouse_button_type.right then
      ErrorHandler.debug_log("[FAVE_BAR] Right-click detected during drag, canceling drag operation", 
        { player = player.name, source_slot = source_slot })
      end_drag(player)
      GameHelpers.player_print(player, {"tf-gui.fave_bar_drag_canceled"})
      return
    end
    
    -- This is a drop attempt
    if handle_drop_on_slot(event, player, slot, favorites) then return end
    
    -- If we get here, the drop didn't work, but we need to exit drag mode anyway
    end_drag(player)
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
  if handle_shift_left_click(event, player, fav, slot, favorites) then return end

  -- Handle Ctrl+click to toggle lock state
  if handle_toggle_lock(event, player, fav, slot, favorites) then return end

  -- Normal left-click to teleport
  if handle_teleport(event, player, fav, slot, false) then return end

  -- Right-click to open tag editor
  handle_request_to_open_tag_editor(event, player, fav, slot)

  -- Update UI
  local main_flow = GuiUtils.get_or_create_gui_flow_from_gui_top(player)
  local bar_frame = GuiUtils.find_child_by_name(main_flow, "fave_bar_frame")
  local bar_flow = bar_frame and GuiUtils.find_child_by_name(bar_frame, "fave_bar_flow")
  if bar_flow then
    fave_bar.update_slot_row(player, bar_flow)
  else
    fave_bar.build(player)
  end
end

local function handle_visible_fave_btns_toggle_click(player)
  local main_flow = GuiUtils.get_or_create_gui_flow_from_gui_top(player)
  if not main_flow or not main_flow.valid then return end
  local slots_row = GuiUtils.find_child_by_name(main_flow, "fave_bar_slots_flow")
  if not slots_row or not slots_row.valid then
    return
  end

  local currently_visible = slots_row.visible
  slots_row.visible = not currently_visible
end

--- Handle favorites bar GUI click events
local function on_fave_bar_gui_click(event)
  local element = event.element
  if not element or not element.valid then return end
  local player = game.get_player(event.player_index)
  if not player or not player.valid then return end

  if element.name:find("^fave_bar_slot_") then
    local favorites = PlayerFavorites.new(player)
    handle_favorite_slot_click(event, player, favorites)
    return
  end

  if element.name == "fave_bar_visible_btns_toggle" then
    local success, err = pcall(handle_visible_fave_btns_toggle_click, player)
    if not success then
      ErrorHandler.debug_log("Handle visible fave buttons toggle failed", {
        player = player.name,
        error = err
      })
    end
  end
end

M.on_fave_bar_gui_click = on_fave_bar_gui_click
M.on_fave_bar_gui_click_impl = on_fave_bar_gui_click

--- Register favorites bar event handlers (deprecated: use central dispatcher)
--- @param script table The Factorio script object
function M.register(script)
  -- Deprecated: do not register directly. Use central dispatcher in control.lua
end

return M
