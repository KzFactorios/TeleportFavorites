-- core/control/slot_interaction_handlers.lua
-- TeleportFavorites Factorio Mod
-- Specialized handlers for slot interactions in the favorites bar: teleportation, lock toggling, drag-and-drop, and tag editing.

local FavoriteRehydration = require("core.favorite.favorite_rehydration")
local FavoriteUtils = require("core.favorite.favorite")
local BasicHelpers = require("core.utils.basic_helpers")
local fave_bar = require("gui.favorites_bar.fave_bar")
local Cache = require("core.cache.cache")
local tag_editor = require("gui.tag_editor.tag_editor")
local GuiValidation = require("core.utils.gui_validation")
local GuiHelpers = require("core.utils.gui_helpers")
local GPSUtils = require("core.utils.gps_utils")
local ErrorHandler = require("core.utils.error_handler")
local LocaleUtils = require("core.utils.locale_utils")
local PlayerHelpers = require("core.utils.player_helpers")
local CursorUtils = require("core.utils.cursor_utils")
local TeleportStrategy = require("core.utils.teleport_strategy")
local SharedUtils = require("core.control.control_shared_utils")

---@class SlotInteractionHandlers
local SlotInteractionHandlers = {}

---@param fav table The favorite to check
---@return boolean can_drag
function SlotInteractionHandlers.can_start_drag(fav)
  return fav and not BasicHelpers.is_blank_favorite(fav) and not BasicHelpers.is_locked_favorite(fav)
end

--- Handle teleportation to a favorite
---@param event table The GUI event
---@param player LuaPlayer The player
---@param fav table The favorite to teleport to
---@param slot number The slot number
---@param did_drag boolean Whether this was part of a drag operation
---@return boolean handled
function SlotInteractionHandlers.handle_teleport(event, player, fav, slot, did_drag)
  if event.button == defines.mouse_button_type.left and not event.control and not did_drag then
    if fav and not FavoriteUtils.is_blank_favorite(fav) then
      if not fav.gps or type(fav.gps) ~= "string" or fav.gps == "" then
        ErrorHandler.warn_log("[SLOT_INTERACTION] Invalid GPS for favorite teleport",
          { slot = slot, fav = fav, player = player and player.name or "<nil>" })
        return false
      end

      local parsed = GPSUtils.parse_gps_string(fav.gps)
      if not parsed or not parsed.x or not parsed.y or not parsed.s then
        ErrorHandler.warn_log("[SLOT_INTERACTION] Invalid GPS coordinates for teleport",
          { slot = slot, gps = fav.gps, fav = fav, player = player and player.name or "<nil>" })
        return false
      end
      local ok, err = pcall(function()
        TeleportStrategy.teleport_to_gps(player, fav.gps)
      end)
      if not ok then
        ErrorHandler.warn_log("[SLOT_INTERACTION] Teleport failed: " .. tostring(err),
          { slot = slot, fav = fav, player = player and player.name or "<nil>" })
        return false
      end
      return true
    end
  end
  return false
end

--- Handle toggle lock state for a favorite
---@param event table The GUI event
---@param player LuaPlayer The player
---@param fav table The favorite
---@param slot number The slot number
---@param favorites table The favorites instance
---@return boolean handled
function SlotInteractionHandlers.handle_toggle_lock(event, player, fav, slot, favorites)
  if event.button == defines.mouse_button_type.left and event.control then
    local success, error_msg = favorites:toggle_favorite_lock(slot)
    if not success then
      PlayerHelpers.error_message_to_player(player,
        LocaleUtils.get_error_string(player, "failed_toggle_lock",
          { error_msg or LocaleUtils.get_error_string(player, "unknown_error") }))
      return false
    end

    -- Update the slot row to reflect lock state change
    local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
    local bar_frame = GuiValidation.find_child_by_name(main_flow, "fave_bar_frame")
    local bar_flow = bar_frame and GuiValidation.find_child_by_name(bar_frame, "fave_bar_flow")
    if bar_flow then
      fave_bar.update_slot_row(player, bar_flow)
    end

    return true
  end
  return false
end

--- Handle shift+left click to start drag
---@param event table The GUI event
---@param player LuaPlayer The player
---@param fav table The favorite
---@param slot number The slot number
---@param favorites table The favorites instance
---@return boolean handled
function SlotInteractionHandlers.handle_shift_left_click(event, player, fav, slot, favorites)
  if event.button == defines.mouse_button_type.left and event.shift then
    ErrorHandler.debug_log("[SLOT_HANDLERS] Handling shift+left click for drag start", {
      player = player.name,
      slot = slot,
      can_drag = SlotInteractionHandlers.can_start_drag(fav),
      fav_is_blank = FavoriteUtils.is_blank_favorite(fav),
      fav_is_locked = BasicHelpers.is_locked_favorite(fav)
    })

    if SlotInteractionHandlers.can_start_drag(fav) then
      local success = CursorUtils.start_drag_favorite(player, fav, slot)
      ErrorHandler.debug_log("[SLOT_HANDLERS] Drag start result", {
        success = success,
        player = player.name,
        slot = slot
      })
      return success
    elseif BasicHelpers.is_locked_favorite(fav) then
      PlayerHelpers.safe_player_print(player, SharedUtils.lstr("tf-gui.fave_bar_locked_cant_drag", slot))
      return true -- Prevent further processing like teleportation
    end
  end
  return false
end

--- Open tag editor from a favorite
---@param player LuaPlayer The player
---@param favorite table The favorite
function SlotInteractionHandlers.open_tag_editor_from_favorite(player, favorite)
  if not favorite then return end

  -- Rehydrate the favorite to ensure all runtime fields are present
  favorite = FavoriteRehydration.rehydrate_favorite_at_runtime(player, favorite)

  -- Create initial tag data from favorite
  local icon = ""
  local text = ""
  if favorite.tag and favorite.tag.chart_tag then
    local valid_check_success, is_valid = pcall(function() return favorite.tag.chart_tag.valid end)
    if valid_check_success and is_valid then
      icon = favorite.tag.chart_tag.icon or ""
      text = favorite.tag.chart_tag.text or ""
    else
      -- Chart tag is invalid, clear the reference
      favorite.tag.chart_tag = nil
    end
  end

  local tag_data = Cache.create_tag_editor_data({
    gps = favorite.gps,
    locked = favorite.locked,
    is_favorite = true, -- Always true when opening from favorites bar
    icon = icon,
    text = text,
    tag = favorite.tag,
    chart_tag = favorite.chart_tag
  })

  -- Persist gps in tag_editor_data
  Cache.set_tag_editor_data(player, tag_data)
  tag_editor.build(player)
end

--- Handle right-click request to open tag editor
---@param event table The GUI event
---@param player LuaPlayer The player
---@param fav table The favorite
---@param slot number The slot number
---@return boolean handled
function SlotInteractionHandlers.handle_request_to_open_tag_editor(event, player, fav, slot)
  if event.button == defines.mouse_button_type.right then
    -- Check if player is currently in a drag operation
    local is_dragging, _ = CursorUtils.is_dragging_favorite(player)
    local player_data = Cache.get_player_data(player)

    if is_dragging then
      ErrorHandler.debug_log("[SLOT_HANDLERS] Right-click detected during drag, canceling drag operation",
        { player = player.name })
      CursorUtils.end_drag_favorite(player)
      PlayerHelpers.safe_player_print(player, { "tf-gui.fave_bar_drag_canceled" })
      return true
    end

    -- Respect suppress_tag_editor flag
    if player_data.suppress_tag_editor and player_data.suppress_tag_editor.tick == game.tick then
      ErrorHandler.debug_log("[SLOT_HANDLERS] Suppress tag editor due to drag cancellation",
        { player = player.name })
      return true
    end

    -- Only open tag editor if not in drag mode
    if fav and not FavoriteUtils.is_blank_favorite(fav) then
      SlotInteractionHandlers.open_tag_editor_from_favorite(player, fav)
      return true
    end
  end
  return false
end

--- Handle reordering of favorites using favorites method
---@param player LuaPlayer The player
---@param favorites table The favorites instance
---@param drag_index number The source slot index
---@param slot number The target slot index
---@return boolean success
function SlotInteractionHandlers.reorder_favorites(player, favorites, drag_index, slot)
  local success, error_msg = favorites:reorder_favorites(drag_index, slot)
  if not success then
    PlayerHelpers.error_message_to_player(player,
      LocaleUtils.get_error_string(player, "failed_reorder_favorite",
        { error_msg or LocaleUtils.get_error_string(player, "unknown_error") }))
    CursorUtils.end_drag_favorite(player)
    return false
  end

  -- Rebuild the entire favorites bar to reflect new order
  fave_bar.build(player)
  CursorUtils.end_drag_favorite(player)
  return true
end

return SlotInteractionHandlers
