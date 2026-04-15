local Deps = require("core.deps_barrel")
local BasicHelpers, ErrorHandler, Cache =
  Deps.BasicHelpers, Deps.ErrorHandler, Deps.Cache
local PlayerFavorites = require("core.favorite.player_favorites")
local FavoriteUtils = require("core.favorite.favorite_utils")
local fave_bar = require("gui.favorites_bar.fave_bar")
local tag_editor = require("gui.tag_editor.tag_editor")
local GuiValidation = require("core.utils.gui_validation")
local GuiHelpers = require("core.utils.gui_helpers")
local CursorUtils = require("core.utils.cursor_utils")
local TeleportEntrypoint = require("core.control.teleport_entrypoint")
local ProfilerExport = require("core.utils.profiler_export")
local TeleportHistoryModal = require("gui.teleport_history_modal.teleport_history_modal")
local SlotInteractionHandlers = {}
function SlotInteractionHandlers.can_start_drag(fav)
  return fav and not FavoriteUtils.is_blank_favorite(fav) and not BasicHelpers.is_locked_favorite(fav)
end
function SlotInteractionHandlers.handle_teleport(event, player, fav, slot, did_drag)
  if event.button == defines.mouse_button_type.left and not event.control and not did_drag then
    if fav and not FavoriteUtils.is_blank_favorite(fav) then
      ErrorHandler.debug_log("[DEBUG] SlotInteractionHandlers.handle_teleport called", {
        slot = slot,
        fav_gps = fav.gps,
        player_name = player and player.name or "<nil>"
      })
      if not fav.gps or type(fav.gps) ~= "string" or fav.gps == "" then
        ErrorHandler.warn_log("[SLOT_INTERACTION] Invalid GPS for favorite teleport",
          { slot = slot, fav = fav, player = player and player.name or "<nil>" })
        return false
      end
      local teleport_success, error_code = TeleportEntrypoint.execute(player, fav.gps, {
        source = "fave_bar",
        add_to_history = true,
        on_success = function(success_player)
          if TeleportHistoryModal.is_open(success_player) then
            TeleportHistoryModal.update_history_list(success_player)
          end
        end,
      })
      if not teleport_success then
        ErrorHandler.warn_log("[SLOT_INTERACTION] Teleport failed: " .. tostring(error_code),
          { slot = slot, fav = fav, player = player and player.name or "<nil>" })
        return false
      end
      return true
    end
  end
  return false
end
function SlotInteractionHandlers.handle_toggle_lock(event, player, fav, slot, favorites)
  if event.button == defines.mouse_button_type.left and event.control then
    local success, error_msg = favorites:toggle_favorite_lock(slot)
    if not success then
      BasicHelpers.error_message_to_player(player,
        BasicHelpers.get_error_string(player, "failed_toggle_lock",
          { error_msg or BasicHelpers.get_error_string(player, "unknown_error") }))
      return false
    end
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
      BasicHelpers.safe_player_print(player, { "tf-gui.fave_bar_locked_cant_drag", slot })
      return true
    end
  end
  return false
end
function SlotInteractionHandlers.open_tag_editor_from_favorite(player, favorite)
  if not favorite then return end
  local action_id = ProfilerExport.begin_action_trace("tag_editor_from_favorite", player.index)
  favorite = PlayerFavorites.rehydrate_favorite_at_runtime(player, favorite)
  local icon = ""
  local text = ""
  if favorite.tag and favorite.tag.chart_tag and favorite.tag.chart_tag.valid then
    icon = favorite.tag.chart_tag.icon or ""
    text = favorite.tag.chart_tag.text or ""
  elseif favorite.tag and favorite.tag.chart_tag then
    favorite.tag.chart_tag = nil
  end
  local tag_data = Cache.create_tag_editor_data({
    gps = favorite.gps,
    locked = favorite.locked,
    is_favorite = true,
    icon = icon,
    text = text,
    tag = favorite.tag,
    chart_tag = favorite.chart_tag
  })
  Cache.set_tag_editor_data(player, tag_data)
  storage._tf_tag_editor_marker_defer_at = storage._tf_tag_editor_marker_defer_at or {}
  storage._tf_tag_editor_marker_defer_at[player.index] = game.tick + 1
  tag_editor.build(player)
  if action_id then
    ProfilerExport.end_action_trace(player.index, action_id)
  end
end
function SlotInteractionHandlers.handle_request_to_open_tag_editor(event, player, fav, slot)
  if event.button == defines.mouse_button_type.right then
    local is_dragging, _ = CursorUtils.is_dragging_favorite(player)
    local player_data = Cache.get_player_data(player)
    if is_dragging then
      ErrorHandler.debug_log("[SLOT_HANDLERS] Right-click detected during drag, canceling drag operation",
        { player = player.name })
      CursorUtils.end_drag_favorite(player)
      BasicHelpers.safe_player_print(player, { "tf-gui.fave_bar_drag_canceled" })
      return true
    end
    if player_data.suppress_tag_editor and player_data.suppress_tag_editor.tick == game.tick then
      ErrorHandler.debug_log("[SLOT_HANDLERS] Suppress tag editor due to drag cancellation",
        { player = player.name })
      return true
    end
    if fav and not FavoriteUtils.is_blank_favorite(fav) then
      SlotInteractionHandlers.open_tag_editor_from_favorite(player, fav)
      return true
    end
  end
  return false
end
function SlotInteractionHandlers.reorder_favorites(player, favorites, drag_index, slot)
  local success, error_msg, changed_indices = favorites:reorder_favorites(drag_index, slot)
  if not success then
    BasicHelpers.error_message_to_player(player,
      BasicHelpers.get_error_string(player, "failed_reorder_favorite",
        { error_msg or BasicHelpers.get_error_string(player, "unknown_error") }))
    CursorUtils.end_drag_favorite(player)
    return false
  end
  if changed_indices and #changed_indices > 0 then
    fave_bar.update_slots_batch(player, changed_indices)
  else
    fave_bar.refresh_slots(player)
  end
  CursorUtils.end_drag_favorite(player)
  return true
end
return SlotInteractionHandlers
