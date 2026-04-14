---@diagnostic disable: undefined-global

-- core/events/chart_tag_helpers.lua
-- TeleportFavorites Factorio Mod
-- Consolidated helper functions for chart tag event handling.
-- Specialized functions: modification validation, removal protection, GPS extraction, tag/favorites updating, position notifications, permission checking.
-- Consolidated from chart_tag_modification_helpers.lua and chart_tag_removal_helpers.lua for better organization and reduced file count.

local Deps = require("core.deps_barrel")
local ErrorHandler, Cache, GPSUtils =
  Deps.ErrorHandler, Deps.Cache, Deps.GpsUtils
local BasicHelpers = Deps.BasicHelpers
local ChartTagUtils = require("core.utils.chart_tag_utils")
local PlayerFavorites = require("core.favorite.player_favorites")
local Tag = require("core.tag.tag")
local fave_bar = require("gui.favorites_bar.fave_bar")
local GuiObserver = require("core.events.gui_observer")
local GuiEventBus = GuiObserver.GuiEventBus

local function rebuild_bars(players)
  for _, p in ipairs(players) do
    if p and p.valid then fave_bar.build(p) end
  end
end

-- ========================================
-- LOCAL FORMATTING UTILITIES
-- ========================================

-- Notification formatting moved to BasicHelpers.format_tag_position_change_notification

---@class ChartTagHelpers
local ChartTagHelpers = {}

-- ====== CHART TAG MODIFICATION HELPERS ======

--- Validate if a tag modification event is valid (moved from handlers.lua)
---@param event table Chart tag modification event
---@param player LuaPlayer|nil Player who triggered the modification
---@return boolean valid True if modification should be processed
function ChartTagHelpers.is_valid_tag_modification(event, player)
  if not player or not player.valid then
    ErrorHandler.debug_log("Chart tag modification rejected: invalid player", { event = event })
    return false
  end
  if not event.tag or not event.tag.valid then
    ErrorHandler.debug_log("Chart tag modification rejected: invalid tag", { event = event, player = player and player.name or nil })
    return false
  end
  if not event.tag.position then
    ErrorHandler.debug_log("Chart tag modification rejected: invalid tag position", { event = event, player = player and player.name or nil })
    return false
  end
  if not event.old_position then
    ErrorHandler.debug_log("Chart tag modification rejected: invalid old position", { event = event, player = player and player.name or nil })
    return false
  end

  -- Get the Tag object from storage to check permissions using Tag.owner_name
  local surface_index = GPSUtils.get_context_surface_index(event.tag, player)
  local old_gps = GPSUtils.gps_from_map_position(event.old_position, surface_index)
  local tag = old_gps and Cache.get_tag_by_gps(player, old_gps) or nil
  
  -- Check permissions using AdminUtils with Tag object (uses Tag.owner_name)
  local can_edit, _is_owner, is_admin_override = ChartTagUtils.can_edit_chart_tag(player, tag)

  if not can_edit then
    ErrorHandler.debug_log("Chart tag modification rejected: insufficient permissions", {
      player_name = player and player.name or nil,
      tag_owner = tag and tag.owner_name or "",
      is_admin = ChartTagUtils.is_admin(player)
    })
    return false
  end

  -- Log admin action if this is an admin override
  if is_admin_override then
    ChartTagUtils.log_admin_action(player, "modify_chart_tag", tag, {})
  end

  return true
end

--- Extract GPS coordinates from tag modification event (moved from handlers.lua)
---@param event table Chart tag modification event
---@param player LuaPlayer|nil Player context for surface fallbacks
---@return string|nil new_gps New GPS coordinate string
---@return string|nil old_gps Old GPS coordinate string
function ChartTagHelpers.extract_gps(event, player)
  local new_gps = nil
  local old_gps = nil

  -- Extract new GPS from event tag position
  if event.tag and event.tag.valid then
    local surface_index = GPSUtils.get_context_surface_index(event.tag, player)
    new_gps = GPSUtils.gps_from_map_position(event.tag.position, surface_index)
  end

  -- Extract old GPS from event if provided
  if event.old_position then
    local surface_index = GPSUtils.get_context_surface_index(event.tag, player)
    old_gps = GPSUtils.gps_from_map_position(event.old_position, surface_index)
  else
    ErrorHandler.debug_log("WARNING: No old_position provided in chart tag modification event", {
      tag_text = event.tag and event.tag.text or "nil",
      new_gps = new_gps
    })
  end

  return new_gps, old_gps
end

--- Update tag data and cleanup old chart tag (moved from handlers.lua)
---@param old_gps string|nil Original GPS coordinate string
---@param new_gps string|nil New GPS coordinate string
---@param event table Chart tag modification event
---@param player LuaPlayer|nil Player context
---@param preserve_owner_name string|nil Optional: explicitly preserve this owner name during the move
function ChartTagHelpers.update_tag_and_cleanup(old_gps, new_gps, event, player, preserve_owner_name)
  if not old_gps or not new_gps then return end

  if not player or not player.valid then
    ErrorHandler.debug_log("Cannot update tag: invalid player", { old_gps = old_gps, new_gps = new_gps })
    return
  end

  local modified_chart_tag = event.tag

  -- Tag moved: old_gps entry is now stale; surgical eviction.
  -- new_gps will be re-queried on next access and cached afresh.
  if old_gps then
    Cache.Lookups.evict_chart_tag_cache_entry(old_gps)
  end

  -- Use new shared helper for tag mutation and surface mapping, preserving ownership
  Tag.update_gps_and_surface_mapping(old_gps, new_gps, modified_chart_tag, player, preserve_owner_name)
end

--- Update all player favorites that reference the old GPS to use new GPS and notify affected players
---@param old_gps string Original GPS coordinates
---@param new_gps string New GPS coordinates
---@param acting_player LuaPlayer Player who made the change
function ChartTagHelpers.update_favorites_gps(old_gps, new_gps, acting_player)
  if not old_gps or not new_gps then return end
  local acting_player_index = acting_player and acting_player.valid and acting_player.index or nil

  -- Update ALL players including the acting player
  local all_affected_players = PlayerFavorites.update_gps_for_all_players(old_gps, new_gps, nil)

  -- Also update the acting player's favorites explicitly if not already included
  if acting_player and acting_player.valid then
    local acting_player_favorites = PlayerFavorites.new(acting_player)
    local acting_player_updated = acting_player_favorites:update_gps_coordinates(old_gps, new_gps)
    local acting_player_already_included = false
    for _, player in ipairs(all_affected_players) do
      if player.index == acting_player_index then
        acting_player_already_included = true
      end
    end
    if acting_player_updated and not acting_player_already_included then
      table.insert(all_affected_players, acting_player)
    end
    -- Tag moved: evict the old GPS entry; new GPS will be cached on next access.
    Cache.Lookups.evict_chart_tag_cache_entry(old_gps)
  end

  rebuild_bars(all_affected_players)

  -- Notify all affected players (excluding the acting player from notifications)
  local notification_players = {}
  for _, player in ipairs(all_affected_players) do
    if player and player.index and player.index ~= acting_player_index then
      table.insert(notification_players, player)
    end
  end

  if #notification_players > 0 then
    local old_position = GPSUtils.map_position_from_gps(old_gps)
    local new_position = GPSUtils.map_position_from_gps(new_gps)
    local chart_tag = Cache.Lookups.get_chart_tag_by_gps(new_gps)
    for _, affected_player in ipairs(notification_players) do
      if affected_player and affected_player.valid then
        local position_msg = BasicHelpers.format_tag_position_change_notification(
          affected_player, chart_tag, old_position or { x = 0, y = 0 }, new_position or { x = 0, y = 0 }
        )
        BasicHelpers.safe_player_print(affected_player, position_msg)
      end
    end
  end
end

--- Update tag metadata (text/icon) for all players who have favorited this tag.
--- Called when tag metadata changes but position remains the same.
--- Emits deferred GuiEventBus.notify calls (one per affected player) instead of
--- calling fave_bar.build directly, so all bar-write cost lands on the next
--- on_nth_tick(2) rather than spiking on the confirm-click / tag-modified tick.
--- If the caller already queued a notify for the acting player (e.g. handle_confirm_btn),
--- the coalescer in gui_observer will merge the duplicate into a single dispatch.
---@param gps string GPS coordinate string
---@param chart_tag LuaCustomChartTag The modified chart tag
---@param acting_player LuaPlayer Player who made the change
function ChartTagHelpers.update_tag_metadata(gps, chart_tag, acting_player)
  if not gps or not chart_tag or not chart_tag.valid then return end
  if not acting_player or not acting_player.valid then return end

  -- Text/icon change: the cached LuaCustomChartTag pointer is still valid (same object);
  -- Factorio reads .text and .icon live, so no cache invalidation needed.

  local surface_tags = Cache.get_surface_tags(acting_player.surface.index)
  local stored_tag = surface_tags and surface_tags[gps]

  local function notify_one(game_player)
    local player_favorites = PlayerFavorites.new(game_player)
    if not player_favorites:get_favorite_by_gps(gps) then return false end
    local affected_slot = nil
    for i, fav in ipairs(player_favorites.favorites) do
      if fav and fav.gps == gps then
        affected_slot = i
        break
      end
    end
    GuiEventBus.notify("cache_updated", {
      type = "tag_metadata_changed",
      player_index = game_player.index,
      gps = gps,
      slot = affected_slot,
    })
    return true
  end

  -- Collect player indices first, then sort so deferred GuiEventBus.notify order matches across peers (pairs() is not ordered).
  local notify_indices = {}
  -- Prefer faved_by_players: map [player_index]=player_index (or true), or legacy array of indices.
  local fbp = stored_tag and stored_tag.faved_by_players
  if fbp and type(fbp) == "table" and next(fbp) ~= nil then
    local seen = {}
    for k, v in pairs(fbp) do
      local pid = nil
      if type(v) == "number" and v >= 1 then
        pid = v
      elseif type(k) == "number" and k >= 1 and (v == true or v == k) then
        pid = k
      end
      if pid and not seen[pid] then
        seen[pid] = true
        local game_player = game.players[pid]
        if game_player and game_player.valid and game_player.connected then
          notify_indices[#notify_indices + 1] = pid
        end
      end
    end
  else
    for _, game_player in pairs(game.connected_players) do
      if game_player and game_player.valid then
        notify_indices[#notify_indices + 1] = game_player.index
      end
    end
  end
  table.sort(notify_indices)
  local notified = 0
  for _, pid in ipairs(notify_indices) do
    local game_player = game.players[pid]
    if game_player and game_player.valid and notify_one(game_player) then
      notified = notified + 1
    end
  end

  ErrorHandler.debug_log("Deferred tag metadata update for affected players", {
    gps = gps,
    players_notified = notified,
    new_text = chart_tag.text or "",
    acting_player = acting_player.name
  })
end

return ChartTagHelpers
