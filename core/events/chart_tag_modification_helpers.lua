---@diagnostic disable: undefined-global
--[[
core/events/chart_tag_modification_helpers.lua
TeleportFavorites Factorio Mod
-----------------------------
Helper functions for chart tag modification event handling, extracted from handlers.lua.

This module contains specialized functions for:
- Chart tag modification validation
- GPS extraction and comparison
- Tag and favorites updating
- Position change notifications

These functions were extracted from large event handlers to improve
maintainability and testability.
]]

local Cache = require("core.cache.cache")
local GPSUtils = require("core.utils.gps_utils")
local ErrorHandler = require("core.utils.error_handler")
local GameHelpers = require("core.utils.game_helpers")
local PlayerFavorites = require("core.favorite.player_favorites")
local RichTextFormatter = require("core.utils.rich_text_formatter")
local AdminUtils = require("core.utils.admin_utils")
local Tag = require("core.tag.tag")
local tag_destroy_helper = require("core.tag.tag_destroy_helper")
local fave_bar = require("gui.favorites_bar.fave_bar")
local Constants = require("constants")
local FavoriteUtils = require("core.favorite.favorite")

---@class ChartTagModificationHelpers
local ChartTagModificationHelpers = {}

--- Validate if a tag modification event is valid (moved from handlers.lua)
---@param event table Chart tag modification event
---@param player LuaPlayer|nil Player who triggered the modification
---@return boolean valid True if modification should be processed
function ChartTagModificationHelpers.is_valid_tag_modification(event, player)
  if not player or not player.valid then return false end
  if not event.tag or not event.tag.valid then return false end

  -- Check permissions using AdminUtils
  local can_edit, is_owner, is_admin_override = AdminUtils.can_edit_chart_tag(player, event.tag)

  if not can_edit then
    ErrorHandler.debug_log("Chart tag modification rejected: insufficient permissions", {
      player_name = player.name,
      chart_tag_last_user = event.tag.last_user and event.tag.last_user.name or "",
      is_admin = AdminUtils.is_admin(player)
    })
    return false
  end

  -- Log admin action if this is an admin override
  if is_admin_override then
    AdminUtils.log_admin_action(player, "modify_chart_tag", event.tag, {
    })
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
function ChartTagModificationHelpers.extract_gps(event, player)
  local new_gps = nil
  local old_gps = nil

  ErrorHandler.debug_log("Extracting GPS from chart tag modification event", {
    has_tag = event.tag ~= nil,
    tag_valid = event.tag and event.tag.valid or false,
    tag_position = event.tag and event.tag.position or "nil",
    has_old_position = event.old_position ~= nil,
    old_position = event.old_position or "nil"
  })

  -- Extract new GPS from event tag position
  if event.tag and event.tag.valid then
    local surface_index = event.tag.surface and event.tag.surface.index or (player and player.valid and player.surface.index) or 1
    new_gps = GPSUtils.gps_from_map_position(event.tag.position, surface_index)
    ErrorHandler.debug_log("New GPS extracted from tag position", {
      position = event.tag.position,
      surface_index = surface_index,
      new_gps = new_gps
    })
  end

  -- Extract old GPS from event if provided
  if event.old_position then
    local surface_index = event.tag and event.tag.surface and event.tag.surface.index or (player and player.valid and player.surface.index) or 1
    old_gps = GPSUtils.gps_from_map_position(event.old_position, surface_index)
    ErrorHandler.debug_log("Old GPS extracted from old_position", {
      old_position = event.old_position,
      surface_index = surface_index,
      old_gps = old_gps
    })
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
function ChartTagModificationHelpers.update_tag_and_cleanup(old_gps, new_gps, event, player)
  if not old_gps or not new_gps then return end

  -- Validate player for Cache.get_tag_by_gps call
  if not player or not player.valid then
    ErrorHandler.debug_log("Cannot update tag: invalid player", { old_gps = old_gps, new_gps = new_gps })
    return
  end

  -- For chart tag modifications, the event.tag IS the chart tag that was modified
  -- We don't need to look up different chart tags - the same tag just moved to a new position
  local modified_chart_tag = event.tag
  
  ErrorHandler.debug_log("Using modified chart tag from event", {
    old_gps = old_gps,
    new_gps = new_gps,
    chart_tag_valid = modified_chart_tag and modified_chart_tag.valid or false,
    chart_tag_position = modified_chart_tag and modified_chart_tag.position or "nil"
  })

  -- Update cache by invalidating the surface to refresh chart tag lookups
  if modified_chart_tag and modified_chart_tag.valid then
    local surface_index = modified_chart_tag.surface and modified_chart_tag.surface.index or player.surface.index
    Cache.Lookups.invalidate_surface_chart_tags(surface_index)
  end

  -- Get or create tag object
  local old_tag = Cache.get_tag_by_gps(player, old_gps)
  if not old_tag then
    old_tag = Tag.new(new_gps, {})
  end

  -- Update tag with new coordinates and chart tag reference
  old_tag.gps = new_gps
  old_tag.chart_tag = modified_chart_tag

  ErrorHandler.debug_log("Updated tag object GPS", {
    old_gps = old_gps,
    new_gps = new_gps,
    tag_gps_after_update = old_tag.gps,
    chart_tag_position = modified_chart_tag and modified_chart_tag.position or "nil"
  })

  -- CRITICAL: Update the surface mapping table from old GPS to new GPS
  local surface_index = GPSUtils.get_surface_index_from_gps(old_gps)
  if surface_index and old_gps ~= new_gps then
    local uint_surface_index = tonumber(surface_index) --[[@as uint]]
    local surface_tags = Cache.get_surface_tags(uint_surface_index)
    if surface_tags[old_gps] then
      -- Move the tag data from old GPS key to new GPS key
      surface_tags[new_gps] = surface_tags[old_gps]
      surface_tags[old_gps] = nil
      ErrorHandler.debug_log("Moved tag data in surface mapping", {
        surface_index = surface_index,
        old_gps = old_gps,
        new_gps = new_gps
      })
    end
    
    -- CRITICAL: Ensure the updated tag is also stored at the new GPS location
    surface_tags[new_gps] = old_tag
    ErrorHandler.debug_log("Ensured updated tag is stored at new GPS location", {
      surface_index = surface_index,
      new_gps = new_gps,
      tag_gps = old_tag.gps,
      tag_has_chart_tag = old_tag.chart_tag ~= nil
    })
    
    -- CRITICAL: Update the lookup table chart_tags_mapped_by_gps
    -- Access the runtime lookup cache directly
    local CACHE_KEY = "Lookups"
    local runtime_cache = _G[CACHE_KEY]
    if runtime_cache and runtime_cache.surfaces and runtime_cache.surfaces[uint_surface_index] then
      local surface_cache = runtime_cache.surfaces[uint_surface_index]
      if surface_cache.chart_tags_mapped_by_gps then
        -- Remove old GPS mapping
        surface_cache.chart_tags_mapped_by_gps[old_gps] = nil
        -- Add new GPS mapping
        surface_cache.chart_tags_mapped_by_gps[new_gps] = modified_chart_tag
        ErrorHandler.debug_log("Updated lookup table chart_tags_mapped_by_gps", {
          surface_index = surface_index,
          old_gps = old_gps,
          new_gps = new_gps,
          chart_tag_valid = modified_chart_tag and modified_chart_tag.valid or false
        })
      end
    else
      -- Force rebuild of lookup cache if it doesn't exist
      Cache.Lookups.invalidate_surface_chart_tags(uint_surface_index)
      ErrorHandler.debug_log("Forced rebuild of lookup cache after GPS change", {
        surface_index = surface_index,
        old_gps = old_gps,
        new_gps = new_gps
      })
    end
  end

  -- No chart tag cleanup needed for chart tag moves - the same tag just moved position
  ErrorHandler.debug_log("Chart tag modification completed - no cleanup needed", {
    old_gps = old_gps,
    new_gps = new_gps,
    chart_tag_valid = modified_chart_tag and modified_chart_tag.valid or false
  })
end

--- Update all player favorites that reference the old GPS to use new GPS and notify affected players (moved from handlers.lua)
---@param old_gps string Original GPS coordinates
---@param new_gps string New GPS coordinates  
---@param acting_player LuaPlayer Player who made the change
function ChartTagModificationHelpers.update_favorites_gps(old_gps, new_gps, acting_player)
  if not old_gps or not new_gps then return end
  local acting_player_index = acting_player and acting_player.valid and acting_player.index or nil

  -- Update ALL players including the acting player
  local all_affected_players = PlayerFavorites.update_gps_for_all_players(old_gps, new_gps, nil) -- Pass nil to include all players

  -- Also update the acting player's favorites explicitly if not already included
  if acting_player and acting_player.valid then
    local acting_player_favorites = PlayerFavorites.new(acting_player)
    local acting_player_updated = acting_player_favorites:update_gps_coordinates(old_gps, new_gps)

    -- Add acting player to affected list if they were updated and not already included
    local acting_player_already_included = false
    for _, player in ipairs(all_affected_players) do
      if player.index == acting_player_index then
        acting_player_already_included = true
        break
      end
    end

    if acting_player_updated and not acting_player_already_included then
      table.insert(all_affected_players, acting_player)
    end
  end

  -- Rebuild favorites bar for all affected players to show updated coordinates
  ErrorHandler.debug_log("Chart tag GPS update - rebuilding favorites bars", {
    affected_players_count = #all_affected_players,
    old_gps = old_gps,
    new_gps = new_gps
  })
  
  for _, affected_player in ipairs(all_affected_players) do
    if affected_player and affected_player.valid then
      ErrorHandler.debug_log("Rebuilding favorites bar for GPS update", {
        player_name = affected_player.name,
        player_index = affected_player.index,
        old_gps = old_gps,
        new_gps = new_gps
      })
      
      -- CRITICAL: Force cache refresh before rebuilding favorites bar
      local surface_index = GPSUtils.get_surface_index_from_gps(new_gps) or 1
      Cache.Lookups.invalidate_surface_chart_tags(tonumber(surface_index))
      
      -- Verify the tag can be found at the new GPS location
      local updated_tag = Cache.get_tag_by_gps(affected_player, new_gps)
      ErrorHandler.debug_log("Cache verification after GPS update", {
        player_name = affected_player.name,
        new_gps = new_gps,
        tag_found = updated_tag ~= nil,
        tag_gps = updated_tag and updated_tag.gps or "nil",
        tag_has_chart_tag = updated_tag and updated_tag.chart_tag ~= nil
      })
      
      fave_bar.build(affected_player)
    end
  end

  -- Notify all affected players (excluding the acting player from notifications)
  local notification_players = {}
  for _, player in ipairs(all_affected_players) do
    if player.index ~= acting_player_index then
      table.insert(notification_players, player)
    end
  end

  if #notification_players > 0 then
    local old_position = GPSUtils.map_position_from_gps(old_gps)
    local new_position = GPSUtils.map_position_from_gps(new_gps)
    local surface_index = 1
    local parts = {}
    for part in string.gmatch(old_gps, "[^.]+") do table.insert(parts, part) end
    if #parts >= 3 then surface_index = tonumber(parts[3]) or 1 end
    local chart_tag = Cache.Lookups.get_chart_tag_by_gps(new_gps)
    for _, affected_player in ipairs(notification_players) do
      if affected_player and affected_player.valid then
        local position_msg = RichTextFormatter.position_change_notification(
          affected_player, chart_tag, old_position or { x = 0, y = 0 }, new_position or { x = 0, y = 0 }
        )
        GameHelpers.player_print(affected_player, position_msg)
      end
    end
  end
end

return ChartTagModificationHelpers
