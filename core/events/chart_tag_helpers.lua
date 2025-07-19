---@diagnostic disable: undefined-global

-- core/events/chart_tag_helpers.lua
-- TeleportFavorites Factorio Mod
-- Consolidated helper functions for chart tag event handling.
-- Specialized functions: modification validation, removal protection, GPS extraction, tag/favorites updating, position notifications, permission checking.
-- Consolidated from chart_tag_modification_helpers.lua and chart_tag_removal_helpers.lua for better organization and reduced file count.

local AdminUtils = require("core.utils.admin_utils")
local Cache = require("core.cache.cache")
local ErrorHandler = require("core.utils.error_handler")
local GPSUtils = require("core.utils.gps_utils")
local LocaleUtils = require("core.utils.locale_utils")
local PlayerFavorites = require("core.favorite.player_favorites")
local PlayerHelpers = require("core.utils.player_helpers")
local Tag = require("core.tag.tag")
local fave_bar = require("gui.favorites_bar.fave_bar")

-- ========================================
-- LOCAL FORMATTING UTILITIES
-- ========================================

-- Notification formatting moved to LocaleUtils.format_tag_position_change_notification

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

  -- Check permissions using AdminUtils
  local can_edit, _is_owner, is_admin_override = AdminUtils.can_edit_chart_tag(player, event.tag)

  if not can_edit then
    ErrorHandler.debug_log("Chart tag modification rejected: insufficient permissions", {
  player_name = player and player.name or nil,
      chart_tag_last_user = event.tag.last_user and event.tag.last_user.name or "",
      is_admin = AdminUtils.is_admin(player)
    })
    return false
  end

  -- Log admin action if this is an admin override
  if is_admin_override then
    AdminUtils.log_admin_action(player, "modify_chart_tag", event.tag, {})
  end

  -- Transfer ownership to admin if last_user is unspecified
  AdminUtils.transfer_ownership_to_admin(event.tag, player)

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
    local surface_index = event.tag.surface and event.tag.surface.index or (player and player.valid and player.surface.index) or 1
    new_gps = GPSUtils.gps_from_map_position(event.tag.position, surface_index)
  end

  -- Extract old GPS from event if provided
  if event.old_position then
    local surface_index = event.tag and event.tag.surface and event.tag.surface.index or (player and player.valid and player.surface.index) or 1
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
function ChartTagHelpers.update_tag_and_cleanup(old_gps, new_gps, event, player)
  if not old_gps or not new_gps then return end

  if not player or not player.valid then
    ErrorHandler.debug_log("Cannot update tag: invalid player", { old_gps = old_gps, new_gps = new_gps })
    return
  end

  local modified_chart_tag = event.tag

  if modified_chart_tag and modified_chart_tag.valid then
    local surface_index = modified_chart_tag.surface and modified_chart_tag.surface.index or player.surface.index
    Cache.Lookups.invalidate_surface_chart_tags(surface_index)
  end

  -- Use new shared helper for tag mutation and surface mapping
  Tag.update_gps_and_surface_mapping(old_gps, new_gps, modified_chart_tag, player)
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
    -- Invalidate chart tag lookups for the surface
    local surface_index = GPSUtils.get_surface_index_from_gps(new_gps)
    Cache.Lookups.invalidate_surface_chart_tags(tonumber(surface_index))
    -- Rebuild favorites bar for affected player
    fave_bar.build(acting_player)
  end

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
        local position_msg = LocaleUtils.format_tag_position_change_notification(
          affected_player, chart_tag, old_position or { x = 0, y = 0 }, new_position or { x = 0, y = 0 }
        )
        PlayerHelpers.safe_player_print(affected_player, position_msg)
      end
    end
  end
end

ChartTagHelpers.ChartTagRemovalHelpers = ChartTagHelpers

return ChartTagHelpers
