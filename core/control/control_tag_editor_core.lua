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
local ChartTagUtils = require("core.utils.chart_tag_utils")
local ChartTagHelpers = require("core.events.chart_tag_helpers")
local GuiObserver = require("core.events.gui_observer")
local GuiEventBus = GuiObserver.GuiEventBus
local Tag = require("core.tag.tag")

local M = {}

-- Session-local queue of deferred Factorio API work (force.add_chart_tag calls).
-- Populated by update_chart_tag_fields on the confirm-click tick.
-- Drained by handle_confirm_btn's on_nth_tick(1) closure on the next tick.
-- Using a queue (not a single slot) in case of future multi-operation paths.
local _deferred_api_work = {}

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

--- Destroy and recreate a chart tag with updated text/icon (multiplayer-safe).
--- The Factorio force.add_chart_tag API call is the most expensive single operation on the
--- confirm-click tick. This function defers it to the next tick via on_nth_tick(1):
---   Tick 0 (confirm click): permission check, old tag destroy (edit path), return.
---   Tick 1 (deferred):      force.add_chart_tag, cache seed, storage/notify update.
--- Returns true if work was successfully queued (or completed inline for the edit path),
--- false if a hard error prevents the operation.
---@param tag table
---@param tag_data table
---@param text string
---@param icon any
---@param player LuaPlayer
---@return boolean ok
function M.update_chart_tag_fields(tag, tag_data, text, icon, player)
  local map_position = GPSUtils.map_position_from_gps(tag.gps)
  if not map_position then
    ErrorHandler.warn_log("Cannot update chart tag: invalid GPS position", { gps = tag.gps })
    return false
  end

  local chart_tag = Cache.Lookups.get_chart_tag_by_gps(tag.gps) or tag_data.chart_tag or tag.chart_tag
  local surface_index = player.surface.index
  local gps = tag.gps

  if chart_tag and chart_tag.valid then
    -- ── EDIT PATH ─────────────────────────────────────────────────────────────
    -- Permission check is synchronous (cheap; no Factorio API cost).
    local can_edit, _, is_admin_override = ChartTagUtils.can_edit_chart_tag(player, tag)
    if not can_edit then
      ErrorHandler.warn_log("Player cannot edit chart tag: insufficient permissions", {
        player_name = player.name,
        tag_owner = tag.owner_name or "",
        is_admin = ChartTagUtils.is_admin(player)
      })
      return false
    end
    if is_admin_override then
      ChartTagUtils.log_admin_action(player, "edit_chart_tag", tag, {
        old_text = chart_tag.text or "",
        new_text = text or "",
        old_icon = chart_tag.icon,
        new_icon = icon
      })
    end

    -- Destroy the old tag NOW (synchronous) so the GPS slot is free for the deferred recreate.
    -- chart_tag.destroy() is cheap compared to force.add_chart_tag.
    surface_index = chart_tag.surface and chart_tag.surface.index or surface_index
    local force   = chart_tag.force
    local surface = chart_tag.surface
    local position = chart_tag.position

    local old_gps_pre = GPSUtils.gps_from_map_position(position, surface_index)
    chart_tag.destroy()
    if old_gps_pre then Cache.Lookups.evict_chart_tag_cache_entry(old_gps_pre) end
    -- Clear the stale ref so handle_confirm_btn doesn't dereference it after we return.
    tag.chart_tag = nil
    tag_data.chart_tag = nil

    local chart_tag_spec = ChartTagUtils.build_spec(position, nil, player, text)
    chart_tag_spec.icon = GuiValidation.has_valid_icon(icon) and icon or nil

    -- Queue the expensive force.add_chart_tag for the next tick.
    -- handle_confirm_btn's single on_nth_tick(1) drains this queue alongside close_tag_editor.
    table.insert(_deferred_api_work, {
      kind          = "recreate",
      force         = force,
      surface       = surface,
      spec          = chart_tag_spec,
      player        = player,
      surface_index = surface_index,
      gps           = gps,
      text          = text,
      position      = position,
    })

  else
    -- ── NEW-CREATION PATH ─────────────────────────────────────────────────────
    -- No existing tag; queue force.add_chart_tag for the next tick.
    local chart_tag_spec = ChartTagUtils.build_spec(map_position, nil, player, text)
    chart_tag_spec.icon = GuiValidation.has_valid_icon(icon) and icon or nil

    table.insert(_deferred_api_work, {
      kind          = "create",
      force         = player.force,
      surface       = player.surface,
      spec          = chart_tag_spec,
      player        = player,
      surface_index = surface_index,
      gps           = gps,
    })
  end

  return true
end

--- Drain all queued deferred Factorio API work (force.add_chart_tag calls).
--- Called from handle_confirm_btn's on_nth_tick(1) closure so there is only
--- one on_nth_tick(1) registration per confirm-click tick.
local function flush_deferred_api_work()
  if #_deferred_api_work == 0 then return end
  local work_items = _deferred_api_work
  _deferred_api_work = {}
  for _, w in ipairs(work_items) do
    local new_ct = ChartTagUtils.safe_add_chart_tag(w.force, w.surface, w.spec, w.player, { skip_collision_check = true })
    if new_ct and new_ct.valid then
      local new_gps = GPSUtils.gps_from_map_position(new_ct.position, w.surface_index)
      if new_gps then Cache.Lookups.seed_chart_tag_in_cache(new_gps, new_ct) end
      local surface_tags = Cache.get_surface_tags(w.surface_index)
      if surface_tags and new_gps and surface_tags[new_gps] then
        surface_tags[new_gps].chart_tag = new_ct
      end
      Cache.invalidate_tag_meta_cache_entry(new_gps)
      if w.kind == "recreate" then
        ChartTagHelpers.update_tag_metadata(new_gps or w.gps, new_ct, w.player)
        ErrorHandler.debug_log("Chart tag recreated (deferred)", { gps = new_gps })
      else
        ErrorHandler.debug_log("Chart tag created (deferred)", { gps = new_gps })
      end
    else
      if w.kind == "recreate" then
        ErrorHandler.error_log("Failed to recreate chart tag after destruction (deferred)", {
          player_name = w.player.name, gps = w.gps, text = w.text
        })
      else
        ErrorHandler.warn_log("Failed to create chart tag (deferred)", {
          gps = w.gps, player_name = w.player.name
        })
      end
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

  -- Mutate favorites storage exactly once, getting back the affected slot index.
  -- Pass silent=true so add/remove don't fire their own notify; we send one below.
  local affected_slot = nil
  if is_favorite then
    local player_favorites = PlayerFavorites.new(player)
    local ok, error_msg, slot = player_favorites:add_favorite(refreshed_tag.gps, true)
    if not ok then
      return M.show_tag_editor_error(player, tag_data,
        BasicHelpers.get_error_string(player, "favorite_slots_full") or error_msg)
    end
    affected_slot = slot
    refreshed_tag.faved_by_players[player.index] = player.index
    Cache.invalidate_rehydrated_favorites()
  else
    local player_favorites = PlayerFavorites.new(player)
    local _, _, slot = player_favorites:remove_favorite(refreshed_tag.gps, true)
    affected_slot = slot
    refreshed_tag.faved_by_players[player.index] = nil
    Cache.invalidate_rehydrated_favorites()
  end

  -- Single targeted notify for the acting player.  update_tag_metadata will emit
  -- deferred notifies for any other players who share this favorited GPS.
  if is_favorite then
    GuiEventBus.notify("favorite_added", {
      player = player,
      player_index = player.index,
      gps = refreshed_tag.gps,
      tag = refreshed_tag,
      slot = affected_slot,
    })
  else
    GuiEventBus.notify("favorite_removed", {
      player = player,
      player_index = player.index,
      gps = refreshed_tag.gps,
      tag = refreshed_tag,
      slot = affected_slot,
    })
  end

  local sanitized_tag2 = Cache.sanitize_for_storage(refreshed_tag)
  tags[refreshed_tag.gps] = sanitized_tag2
  tag_data.tag = sanitized_tag2

  GuiEventBus.notify("cache_updated", {
    type = "tag_editor_confirmed",
    gps = tag.gps,
    player_index = player.index,
    slot = affected_slot,
  })

  if tag_data and tag_data.gps then
    Cache.gps_move_in_progress[tag_data.gps] = nil
  end

  -- Single on_nth_tick(1) handles both the deferred force.add_chart_tag work and the
  -- GUI destruction, so there is exactly one handler registration per confirm-click tick.
  script.on_nth_tick(1, function()
    script.on_nth_tick(1, nil)
    flush_deferred_api_work()
    M.close_tag_editor(player)
  end)
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
  -- silent=true: we send the targeted notify below with the returned slot index.
  local _, _, removed_slot = player_favorites:remove_favorite(tag_gps, true)

  tag_destroy_helper.destroy_tag_and_chart_tag(tag, tag.chart_tag)

  GuiEventBus.notify("favorite_removed", {
    player = player,
    player_index = player.index,
    gps = tag_gps,
    tag = tag,
    slot = removed_slot,
  })

  Cache.invalidate_rehydrated_favorites()

  M.dismiss_delete_confirm(player)
  M.close_tag_editor(player)
  Cache.set_tag_editor_delete_mode(player, false)
end

return M
