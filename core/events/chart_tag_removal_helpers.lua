---@diagnostic disable: undefined-global
--[[
core/events/chart_tag_removal_helpers.lua
TeleportFavorites Factorio Mod
-----------------------------
Helper functions for chart tag removal event handling, extracted from handlers.lua.

This module contains specialized functions for:
- Chart tag removal validation
- Favorites ownership checking
- Admin permissions handling
- Chart tag recreation for protected tags

These functions were extracted from large event handlers to improve
maintainability and testability.
]]

local Cache = require("core.cache.cache")
local GPSUtils = require("core.utils.gps_utils")
local GameHelpers = require("core.utils.game_helpers")
local AdminUtils = require("core.utils.admin_utils")
local ChartTagSpecBuilder = require("core.utils.chart_tag_spec_builder")
local ChartTagUtils = require("core.utils.chart_tag_utils")
local RichTextFormatter = require("core.utils.rich_text_formatter")
local tag_destroy_helper = require("core.tag.tag_destroy_helper")

---@class ChartTagRemovalHelpers
local ChartTagRemovalHelpers = {}

--- Validate if chart tag removal should be processed
---@param event table Chart tag removal event
---@return boolean should_process Whether to process the removal
---@return LuaCustomChartTag? chart_tag The chart tag being removed
function ChartTagRemovalHelpers.validate_removal_event(event)
  if not event or not event.tag or not event.tag.valid then 
    return false, nil 
  end
  
  local chart_tag = event.tag
  
  -- Short circuit if there is no text or icon - it is not a valid MOD tag
  if chart_tag and not chart_tag.icon and (not chart_tag.text or chart_tag.text == "") then 
    return false, nil 
  end
  
  return true, chart_tag
end

--- Check if other players have favorites for this tag
---@param tag table Tag object from cache
---@param removing_player LuaPlayer Player attempting to remove the tag
---@return boolean has_other_favorites Whether other players have this favorited
function ChartTagRemovalHelpers.has_other_players_favorites(tag, removing_player)
  if not tag or not tag.faved_by_players or #tag.faved_by_players == 0 then
    return false
  end
  
  for _, fav_player_index in ipairs(tag.faved_by_players) do
    local fav_player = game.get_player(fav_player_index)
    if fav_player and fav_player.valid and fav_player.name ~= removing_player.name then
      return true
    end
  end
  
  return false
end

--- Recreate chart tag that was protected from deletion
---@param chart_tag LuaCustomChartTag Original chart tag that was removed
---@param player LuaPlayer Player who attempted the removal
---@param surface_index number Surface index for cache invalidation
---@return boolean success Whether recreation was successful
function ChartTagRemovalHelpers.recreate_protected_chart_tag(chart_tag, player, surface_index)
  -- Create chart tag spec using centralized builder
  local chart_tag_spec = ChartTagSpecBuilder.build(chart_tag.position, chart_tag, player, nil, true)
  
  local new_chart_tag = ChartTagUtils.safe_add_chart_tag(player.force, chart_tag.surface, chart_tag_spec, player)
  
  if new_chart_tag and new_chart_tag.valid then
    -- Update the tag with the new chart tag reference
    local gps = GPSUtils.gps_from_map_position(chart_tag.position, surface_index)
    local tag = Cache.get_tag_by_gps(player, gps)
    if tag then
      tag.chart_tag = new_chart_tag
    end
    
    -- Refresh the cache
    Cache.Lookups.invalidate_surface_chart_tags(surface_index)
    
    -- Notify the player
    local deletion_msg = RichTextFormatter.deletion_prevention_notification(new_chart_tag)
    GameHelpers.player_print(player, deletion_msg)
    
    return true
  end
  
  return false
end

--- Handle chart tag removal with permission and favorite checking
---@param chart_tag LuaCustomChartTag Chart tag being removed
---@param player LuaPlayer Player attempting removal
---@param tag table? Tag object from cache
---@param surface_index number Surface index
---@return boolean should_destroy Whether the tag should be destroyed
function ChartTagRemovalHelpers.handle_protected_removal(chart_tag, player, tag, surface_index)
  if not tag or not tag.faved_by_players or #tag.faved_by_players == 0 then
    return true -- No protection needed, allow destruction
  end
  
  local has_other_favorites = ChartTagRemovalHelpers.has_other_players_favorites(tag, player)
  
  -- Use AdminUtils to check if deletion should be prevented
  local can_delete, _is_owner, is_admin_override = AdminUtils.can_delete_chart_tag(player, chart_tag, tag)
  
  -- If deletion is not allowed (non-admin and other players have favorites), prevent it
  if has_other_favorites and not can_delete then
    local success = ChartTagRemovalHelpers.recreate_protected_chart_tag(chart_tag, player, surface_index)
    return not success -- If recreation failed, allow destruction as fallback
  elseif is_admin_override then
    -- Log admin action for forced deletion
    AdminUtils.log_admin_action(player, "force_delete_chart_tag", chart_tag, {
      had_other_favorites = has_other_favorites,
      override_reason = "admin_privileges"
    })
  end
  
  return true -- Allow destruction
end

return ChartTagRemovalHelpers
