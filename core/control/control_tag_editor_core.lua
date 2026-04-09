---@diagnostic disable: undefined-global, assign-type-mismatch, param-type-mismatch

-- core/control/control_tag_editor_core.lua
-- Heavy-lifting operations extracted from control_tag_editor.lua.
-- Provides: close_tag_editor, show_tag_editor_error, update_chart_tag_fields,
--           handle_confirm_btn, _dismiss_delete_confirm, handle_delete_confirm

local Deps = require("deps")
local BasicHelpers, ErrorHandler, Cache, Constants, GPSUtils, Enum =
  Deps.BasicHelpers, Deps.ErrorHandler, Deps.Cache, Deps.Constants, Deps.GpsUtils, Deps.Enum
local tag_editor = require("gui.tag_editor.tag_editor")
local GuiValidation = require("core.utils.gui_validation")
local tag_destroy_helper = require("core.tag.tag_destroy_helper")
local PlayerFavorites = require("core.favorite.player_favorites")
local FavoriteUtils = require("core.favorite.favorite_utils")
local ChartTagUtils = require("core.utils.chart_tag_utils")
local ChartTagHelpers = require("core.events.chart_tag_helpers")
local GuiObserver = require("core.events.gui_observer")
local GuiEventBus = GuiObserver.GuiEventBus
local Tag = require("core.tag.tag")

local M = {}

--- Update error message in the tag editor UI and cache
---@param player LuaPlayer
---@param tag_data table
---@param message string
function M.show_tag_editor_error(player, tag_data, message)
  tag_data.error_message = message
  BasicHelpers.update_error_message(tag_editor.update_error_message, player, message)
  Cache.set_tag_editor_data(player, tag_data)
end

--- Close and clean up the tag editor GUI
---@param player LuaPlayer
function M.close_tag_editor(player)
  local tag_data = Cache.get_tag_editor_data(player)
  local was_move_mode = tag_data and tag_data.move_mode == true
  if was_move_mode then
    if BasicHelpers.is_valid_player(player) then
      player.clear_cursor()
    end
    -- MULTIPLAYER FIX: Do NOT deregister on_player_selected_area here.
    -- These events are permanently registered by ModalInputBlocker at load time.
  end
  Cache.set_tag_editor_data(player, {})
  GuiValidation.safe_destroy_frame(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR)
  player.opened = nil
end

--- Destroy and recreate a chart tag with updated text/icon (multiplayer-safe)
---@param tag table
---@param tag_data table
---@param text string
---@param icon any
---@param player LuaPlayer
function M.update_chart_tag_fields(tag, tag_data, text, icon, player)
  local map_position = GPSUtils.map_position_from_gps(tag.gps)
  if not map_position then
    ErrorHandler.warn_log("Cannot update chart tag: invalid GPS position", { gps = tag.gps })
    return
  end

  local chart_tag = Cache.Lookups.get_chart_tag_by_gps(tag.gps) or tag_data.chart_tag or tag.chart_tag

  if chart_tag and chart_tag.valid then
    local can_edit, is_owner, is_admin_override = ChartTagUtils.can_edit_chart_tag(player, tag)
    if not can_edit then
      ErrorHandler.warn_log("Player cannot edit chart tag: insufficient permissions", {
        player_name = player.name,
        tag_owner = tag.owner_name or "",
        is_admin = ChartTagUtils.is_admin(player)
      })
      return
    end
    if is_admin_override then
      ChartTagUtils.log_admin_action(player, "edit_chart_tag", tag, {
        old_text = chart_tag.text or "",
        new_text = text or "",
        old_icon = chart_tag.icon,
        new_icon = icon
      })
    end

    -- MULTIPLAYER FIX: Destroy and recreate instead of direct modification
    local surface_index = chart_tag.surface and chart_tag.surface.index or player.surface.index
    local force = chart_tag.force
    local surface = chart_tag.surface
    local position = chart_tag.position

    ErrorHandler.debug_log("Destroying chart tag for multiplayer-safe recreation", {
      player_name = player.name,
      position = position,
      old_text = chart_tag.text or "",
      old_icon = chart_tag.icon,
      tag_owner = tag.owner_name or ""
    })

    -- Surgical eviction: old GPS entry is now stale (same position, tag destroyed).
    local old_gps_pre = GPSUtils.gps_from_map_position(position, surface_index)
    chart_tag.destroy()
    if old_gps_pre then Cache.Lookups.evict_chart_tag_cache_entry(old_gps_pre) end

    local chart_tag_spec = ChartTagUtils.build_spec(position, nil, player, text)
    if GuiValidation.has_valid_icon(icon) then
      chart_tag_spec.icon = icon
    else
      chart_tag_spec.icon = nil
    end

    local new_chart_tag = ChartTagUtils.safe_add_chart_tag(force, surface, chart_tag_spec, player)
    if new_chart_tag and new_chart_tag.valid then
      tag.chart_tag = new_chart_tag
      tag_data.chart_tag = new_chart_tag

      local gps = GPSUtils.gps_from_map_position(new_chart_tag.position, surface_index)
      ErrorHandler.debug_log("Chart tag recreated for multiplayer safety", {
        surface_index = surface_index,
        new_chart_tag_gps = gps,
        tag_owner = tag.owner_name or ""
      })

      local refreshed_chart_tag = Cache.Lookups.get_chart_tag_by_gps(gps)
      if refreshed_chart_tag and refreshed_chart_tag.valid then
        tag.chart_tag = refreshed_chart_tag
        tag_data.chart_tag = refreshed_chart_tag
        tag_data.tag = tag
      end

      -- Manually rebuild favorites bars for all affected players (destroy-recreate doesn't fire on_chart_tag_modified)
      ChartTagHelpers.update_tag_metadata(gps, new_chart_tag, player)
    else
      ErrorHandler.error_log("Failed to recreate chart tag after destruction", {
        player_name = player.name,
        position = position,
        text = text,
        icon = icon
      })
      return
    end
  else
    local chart_tag_spec = ChartTagUtils.build_spec(map_position, nil, player, text)
    if GuiValidation.has_valid_icon(icon) then
      chart_tag_spec.icon = icon
    else
      chart_tag_spec.icon = nil
    end

    local new_chart_tag = ChartTagUtils.safe_add_chart_tag(player.force, player.surface, chart_tag_spec, player)
    if new_chart_tag and new_chart_tag.valid then
      tag.chart_tag = new_chart_tag

      local surface_index = player.surface.index
      local gps = GPSUtils.gps_from_map_position(new_chart_tag.position, surface_index)
      ErrorHandler.debug_log("Chart tag created", {
        surface_index = surface_index,
        new_chart_tag_gps = gps
      })
      local refreshed_chart_tag = Cache.Lookups.get_chart_tag_by_gps(gps)
      if refreshed_chart_tag and refreshed_chart_tag.valid then
        tag.chart_tag = refreshed_chart_tag
        tag_data.chart_tag = refreshed_chart_tag
        tag_data.tag = tag
      end
    else
      ErrorHandler.warn_log("Failed to create chart tag", {
        gps = tag.gps,
        text = text,
        force_name = player.force and player.force.name or "unknown",
        force_valid = player.force and player.force.valid or false,
        surface_name = player.surface and player.surface.name or "unknown",
        player_name = player.name
      })
      return M.show_tag_editor_error(player, tag_data,
        BasicHelpers.get_error_string(player, "chart_tag_creation_failed") or
        "Failed to create map tag. You may not have permission to create tags on this surface.")
    end
  end

end

--- Handle the confirm button press in the tag editor
---@param player LuaPlayer
---@param element any GUI element (unused, for signature compat)
---@param tag_data table
function M.handle_confirm_btn(player, element, tag_data)
  if tag_data and tag_data.gps then
    Cache.gps_move_in_progress[tag_data.gps] = true
  end
  ErrorHandler.debug_log("[TAG_EDITOR] handle_confirm_btn: entry", {
    gps = tag_data and tag_data.gps,
    is_favorite = tag_data and tag_data.is_favorite
  })

  local text = (tag_data.text or ""):gsub("%s+$", "")
  local icon = tag_data.icon or ""
  local is_favorite = tag_data.is_favorite
  local max_len = Constants.settings.TAG_TEXT_MAX_LENGTH
  if #text > max_len then
    return M.show_tag_editor_error(player, tag_data,
      BasicHelpers.get_error_string(player, "tag_text_length_exceeded", { tostring(max_len) }))
  end

  local has_valid_icon = GuiValidation.has_valid_icon(icon)
  if text == "" and not has_valid_icon then
    return M.show_tag_editor_error(player, tag_data,
      BasicHelpers.get_error_string(player, "tag_requires_icon_or_text"))
  end

  local surface_index = player.surface.index
  local tags = Cache.get_surface_tags(surface_index)
  local tag = tag_data.tag or {}

  if not tag.gps and tag_data.gps then tag.gps = tag_data.gps end
  if not tag.chart_tag and tag_data.chart_tag then tag.chart_tag = tag_data.chart_tag end

  if tag.gps then
    if not tags[tag.gps] then
      tags[tag.gps] = Tag.new(tag.gps, {}, player.name)
      ErrorHandler.debug_log("[OWNER][handle_confirm_btn] Created new Tag object with owner_name", {
        gps = tag.gps, owner_name = player.name
      })
    end
    if not tags[tag.gps].owner_name then
      tags[tag.gps].owner_name = player.name
    end
    tag.owner_name = tags[tag.gps].owner_name
  end

  M.update_chart_tag_fields(tag, tag_data, text, icon, player)

  local refreshed_tag = tags[tag.gps] or tag
  refreshed_tag.faved_by_players = refreshed_tag.faved_by_players or {}

  if tag.chart_tag and tag.chart_tag.valid then
    refreshed_tag.chart_tag = tag.chart_tag
  end
  refreshed_tag.owner_name = refreshed_tag.owner_name or player.name
  tag_data.tag = refreshed_tag

  local sanitized_tag = Cache.sanitize_for_storage(refreshed_tag)
  tags[tag.gps] = sanitized_tag

  if is_favorite then
    local player_favorites = PlayerFavorites.new(player)
    local _, error_msg = player_favorites:add_favorite(refreshed_tag.gps)
    if error_msg then
      return M.show_tag_editor_error(player, tag_data,
        BasicHelpers.get_error_string(player, "favorite_slots_full") or error_msg)
    end
    refreshed_tag.faved_by_players[player.index] = player.index
    Cache.invalidate_rehydrated_favorites()
  else
    local player_favorites = PlayerFavorites.new(player)
    player_favorites:remove_favorite(refreshed_tag.gps)
    refreshed_tag.faved_by_players[player.index] = nil
    Cache.invalidate_rehydrated_favorites()
  end

  local function is_data_synced()
    local player_favorites = PlayerFavorites.new(player)
    local all_synced = true
    for i, fav in ipairs(player_favorites.favorites) do
      if fav and not FavoriteUtils.is_blank_favorite(fav) then
        if fav.gps ~= refreshed_tag.gps then
          ErrorHandler.debug_log("[TAG_EDITOR][SYNC CHECK] Slot not synced", {slot=i, fav_gps=fav.gps, expected=refreshed_tag.gps})
          all_synced = false
        end
        if fav.tag and fav.tag.gps ~= refreshed_tag.gps then
          ErrorHandler.debug_log("[TAG_EDITOR][SYNC CHECK] Tag in slot not synced", {slot=i, tag_gps=fav.tag.gps, expected=refreshed_tag.gps})
          all_synced = false
        end
      end
    end
    return all_synced
  end

  local function deferred_notify_with_sync_check(max_attempts, attempt)
    attempt = attempt or 1
    if is_data_synced() or attempt >= max_attempts then
      if not is_data_synced() then
        ErrorHandler.debug_log("[TAG_EDITOR][SYNC CHECK] Data not fully synced after max attempts", {attempt=attempt})
      end
      if is_favorite then
        GuiEventBus.notify("favorite_added", {
          player = player,
          gps = refreshed_tag.gps,
          tag = refreshed_tag
        })
      else
        GuiEventBus.notify("favorite_removed", {
          player = player,
          gps = refreshed_tag.gps,
          tag = refreshed_tag
        })
      end
      GuiEventBus.notify("cache_updated", {
        type = "favorites_gps_updated",
        player_index = player.index,
        old_gps = tag_data.gps,
        new_gps = refreshed_tag.gps
      })
    else
      -- on_nth_tick(N) is an interval (fires when tick % N == 0), not an absolute tick.
      -- Run once on the next tick pass: interval 1, then unregister before retrying.
      script.on_nth_tick(1, function()
        script.on_nth_tick(1, nil)
        deferred_notify_with_sync_check(max_attempts, attempt + 1)
      end)
    end
  end

  deferred_notify_with_sync_check(3, 1)

  local sanitized_tag2 = Cache.sanitize_for_storage(refreshed_tag)
  tags[refreshed_tag.gps] = sanitized_tag2
  tag_data.tag = sanitized_tag2

  GuiEventBus.notify("cache_updated", { type = "tag_editor_confirmed", gps = tag.gps })

  if tag_data and tag_data.gps then
    Cache.gps_move_in_progress[tag_data.gps] = nil
  end

  M.close_tag_editor(player)
end

--- Close the delete confirmation dialog
---@param player LuaPlayer
function M.dismiss_delete_confirm(player)
  GuiValidation.safe_destroy_frame(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR_DELETE_CONFIRM)
  Cache.set_modal_dialog_state(player, nil)
end

--- Handle delete confirmation
---@param player LuaPlayer
function M.handle_delete_confirm(player)
  local tag_data = Cache.get_tag_editor_data(player)
  if not tag_data then
    M.dismiss_delete_confirm(player)
    M.close_tag_editor(player)
    return
  end

  local tag = tag_data.tag
  if not tag then
    M.dismiss_delete_confirm(player)
    M.close_tag_editor(player)
    Cache.set_tag_editor_delete_mode(player, false)
    return
  end

  local can_delete, _is_owner, is_admin_override, reason = ChartTagUtils.can_delete_chart_tag(player, tag)
  if not can_delete then
    M.dismiss_delete_confirm(player)
    M.show_tag_editor_error(player, tag_data, reason or BasicHelpers.get_error_string(player, "tag_deletion_forbidden"))
    Cache.set_tag_editor_delete_mode(player, false)
    return
  end

  if is_admin_override then
    ChartTagUtils.log_admin_action(player, "delete_chart_tag", tag, {
      had_other_favorites = tag.faved_by_players and #tag.faved_by_players > 1,
      override_reason = "admin_privileges"
    })
  end

  local tag_gps = tag.gps
  local player_favorites = PlayerFavorites.new(player)
  player_favorites:remove_favorite(tag_gps)

  tag_destroy_helper.destroy_tag_and_chart_tag(tag, tag.chart_tag)

  GuiEventBus.notify("favorite_removed", { player = player, gps = tag_gps, tag = tag })

  Cache.invalidate_rehydrated_favorites()

  M.dismiss_delete_confirm(player)
  M.close_tag_editor(player)
  Cache.set_tag_editor_delete_mode(player, false)
end

return M
