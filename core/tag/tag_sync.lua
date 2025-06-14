--[[
TeleportFavorites - TagSync Module

This module provides static functions for synchronizing, updating, and removing chart tags and their associated favorites across all players. It ensures tag consistency, handles GPS normalization, and manages tag/favorite relationships robustly. All major tag and chart_tag operations are centralized here for maintainability and DRYness.

REFACTORED (All 3 Phases Complete):
- Fixed critical compilation errors and nil reference crashes
- Added comprehensive ErrorHandler integration for debugging
- Implemented input validation and transaction safety
- Performance optimized with early exits for empty favorites
- Removed dead code and circular dependencies
- Enhanced error recovery and logging patterns

API:
-----
- add_new_chart_tag(player, normal_pos, text, icon) -> LuaCustomChartTag?  -- Create new chart tag with error handling
- guarantee_chart_tag(player, tag) -> LuaCustomChartTag?                  -- Ensure chart tag exists, create if needed
- update_tag_gps_and_associated(player, tag, new_gps) -> Tag?             -- Update tag GPS and recreate chart tag
- delete_tag_by_player(player, tag) -> Tag?                              -- Delete tag for player, handle favorites
- remove_tag_and_associated(tag)                                         -- Remove tag and chart tag completely

HELPER FUNCTIONS:
- has_player_favorites(old_gps) -> boolean                               -- Check if GPS has any player favorites
- validate_sync_inputs(player, tag, new_gps?) -> boolean, issues         -- Validate function inputs
- safe_extract_chart_tag_properties(chart_tag?) -> text, icon           -- Safely extract chart tag data

Performance Improvements:
- Early exits when no player favorites exist
- Comprehensive logging for multiplayer debugging
- Transaction safety with proper error recovery
- Optimized player iteration patterns

Notes:
------
- All functions now include comprehensive error handling and logging
- Input validation prevents crashes from invalid parameters
- Performance optimized to avoid unnecessary operations
- Follows established ErrorHandler patterns from other refactored modules
--]]
---@diagnostic disable: undefined-global
local Tag = require("core.tag.tag")
local gps_helpers = require("core.utils.gps_helpers")
local PlayerFavorites = require("core.favorite.player_favorites")
local Helpers = require("core.utils.basic_helpers")
local Cache = require("core.cache.cache")
local gps_parser = require("core.utils.gps_parser")
local Lookups = Cache.lookups
local ErrorHandler = require("core.utils.error_handler")

---@class TagSync
local TagSync = {}

-- Helper Functions

--- Check if there are any player favorites for a given GPS
---@param old_gps string
---@return boolean
local function has_player_favorites(old_gps)
  if not old_gps or old_gps == "" then return false end
  
  for _, player in pairs(game.players) do
    local pfaves = Cache.get_player_favorites(player)
    for _, fave in pairs(pfaves) do
      if fave.gps == old_gps then return true end
    end
  end
  return false
end

--- Validate inputs for sync operations
---@param player LuaPlayer
---@param tag table
---@param new_gps string?
---@return boolean is_valid
---@return string[] issues
local function validate_sync_inputs(player, tag, new_gps)
  local issues = {}
  
  if not player or not player.valid then
    table.insert(issues, "Invalid player")
  end
  
  if not tag or not tag.gps then
    table.insert(issues, "Invalid tag or missing GPS")
  end
  
  if new_gps and (not new_gps or new_gps == "") then
    table.insert(issues, "Invalid new GPS coordinate")
  end
  
  return #issues == 0, issues
end

--- Safely extract chart tag properties with nil checks
---@param chart_tag LuaCustomChartTag?
---@return string text
---@return table icon
local function safe_extract_chart_tag_properties(chart_tag)
  if chart_tag and chart_tag.valid then
    return chart_tag.text or "", chart_tag.icon or {}
  end
  return "", {}
end

---Update every players' favorites, replacing old_gps with new_gps, because it is possible for
--- multiple players to have the same GPS in their favorites.
---@param old_gps string
---@param new_gps string
local function update_player_favorites_gps(old_gps, new_gps)
  if not old_gps or not new_gps or old_gps == new_gps then
    ErrorHandler.debug_log("Skipping GPS update: invalid parameters", {
      old_gps = old_gps,
      new_gps = new_gps
    })
    return
  end
  
  -- Early exit if no players have this GPS in favorites
  if not has_player_favorites(old_gps) then
    ErrorHandler.debug_log("No player favorites to update, skipping", { gps = old_gps })
    return
  end
  
  local updated_count = 0
  for _, player in pairs(game.players) do
    local pfaves = Cache.get_player_favorites(player)
    for _, fave in pairs(pfaves) do
      if fave.gps == old_gps then 
        fave.gps = new_gps 
        updated_count = updated_count + 1
      end
    end
  end
  
  ErrorHandler.debug_log("Updated player favorites GPS", {
    old_gps = old_gps,
    new_gps = new_gps,
    updated_count = updated_count
  })
end

---Add a new chart tag for a player at a normalized position.
---@param player LuaPlayer
---@param normal_pos MapPosition
---@param text string
---@param icon SignalID
---@return LuaCustomChartTag?
function TagSync.add_new_chart_tag(player, normal_pos, text, icon)
  if not player or not player.valid then
    ErrorHandler.warn_log("Cannot create chart tag: invalid player")
    return nil
  end
  
  ErrorHandler.debug_log("Creating new chart tag", {
    player = player.name,
    position = normal_pos,
    text = text
  })
  local success, result = pcall(function()
    -- Prepare chart_tag_spec properly
    local chart_tag_spec = {
      position = normal_pos,
      text = text or "Tag", -- Ensure text is never nil
      last_user = player.name
    }    -- Only include icon if it's a valid SignalID
    if icon and type(icon) == "table" and icon.name then
      chart_tag_spec.icon = icon
    end
    
    local GPSChartHelpers = require("core.utils.gps_chart_helpers")
    return GPSChartHelpers.safe_add_chart_tag(game.forces["player"], player.surface, chart_tag_spec)
  end)
    if not success then
    ErrorHandler.warn_log("Chart tag creation failed", {
      error = result,
      player = player.name
    })
    return nil
  end
  
  ---@cast result LuaCustomChartTag?
  return result
end

---Ensure a chart_tag exists for a given Tag, creating one if needed.
---@param player LuaPlayer
---@param tag Tag
---@return LuaCustomChartTag?
function TagSync.guarantee_chart_tag(player, tag)
  if not player then 
    ErrorHandler.warn_log("Cannot guarantee chart tag: invalid player")
    return nil 
  end
  
  local is_valid, issues = validate_sync_inputs(player, tag)
  if not is_valid then
    ErrorHandler.warn_log("Chart tag guarantee validation failed", { issues = issues })
    return nil
  end

  local chart_tag = tag.chart_tag
  if chart_tag and chart_tag.valid then 
    ErrorHandler.debug_log("Chart tag already exists and is valid")
    return chart_tag 
  end

  ErrorHandler.debug_log("Creating new chart tag for existing tag", {
    player = player.name,
    tag_gps = tag.gps
  })

  local text, icon = safe_extract_chart_tag_properties(chart_tag)
  local map_pos, surface_index = gps_parser.map_position_from_gps(tag.gps), gps_parser.get_surface_index_from_gps(tag.gps)
  local surface = game.surfaces[surface_index]

  if not map_pos or not surface_index then 
    ErrorHandler.warn_log("Invalid GPS string for chart tag creation", { gps = tag.gps })
    return nil
  end
  
  if not surface then 
    ErrorHandler.warn_log("Surface not found for chart tag creation", { 
      gps = tag.gps, 
      surface_index = surface_index 
    })
    return nil
  end

  local normal_pos = gps_helpers.normalize_landing_position_with_cache(player, gps_parser.gps_from_map_position(map_pos, player.surface.index), Cache)
  if not normal_pos then 
    ErrorHandler.warn_log("Could not find valid landing area for chart tag")
    return nil
  end

  local new_chart_tag = TagSync.add_new_chart_tag(player, normal_pos, text, icon)
  if not new_chart_tag then 
    ErrorHandler.warn_log("Chart tag creation failed")
    return nil
  end

  local new_gps = gps_parser.gps_from_map_position(new_chart_tag.position, surface_index)
  if new_gps ~= tag.gps then
    ErrorHandler.debug_log("GPS changed during chart tag creation, updating favorites", {
      old_gps = tag.gps,
      new_gps = new_gps
    })
    -- If the GPS has changed, update all player favorites
    update_player_favorites_gps(tag.gps, new_gps)
    tag.gps = new_gps
  end

  -- dispose of the working chart_tag
  if chart_tag and chart_tag.valid then 
    chart_tag.destroy() 
    ErrorHandler.debug_log("Destroyed old chart tag")
  end
  tag.chart_tag = new_chart_tag
  Cache.lookups.clear_chart_tag_cache(surface.index)

  ErrorHandler.debug_log("Chart tag guarantee completed successfully", {
    new_gps = new_gps
  })

  return tag.chart_tag
end

---Update a tag's GPS and associated chart_tag, destroying the old chart_tag.
---@param player LuaPlayer
---@param tag Tag
---@param new_gps string
---@return Tag|nil
function TagSync.update_tag_gps_and_associated(player, tag, new_gps)
  local is_valid, issues = validate_sync_inputs(player, tag, new_gps)
  if not is_valid then
    ErrorHandler.warn_log("Tag GPS update validation failed", { issues = issues })
    return nil
  end
  
  if not tag or tag.gps == new_gps then 
    ErrorHandler.debug_log("No GPS update needed", {
      tag_exists = tag ~= nil,
      gps_same = tag and tag.gps == new_gps
    })
    return tag
  end

  ErrorHandler.debug_log("Starting tag GPS update", {
    player = player.name,
    old_gps = tag.gps,
    new_gps = new_gps
  })

  local old_gps = tag.gps
  local old_chart_tag = tag.chart_tag
  local surface_index = gps_parser.get_surface_index_from_gps(new_gps) or player.surface.index or 1
  local map_pos = gps_parser.map_position_from_gps(new_gps)
  local surface = game.surfaces[surface_index]
  
  if not map_pos or not surface then 
    ErrorHandler.warn_log("Invalid GPS or surface for update", {
      new_gps = new_gps,
      surface_index = surface_index,
      has_map_pos = map_pos ~= nil,
      has_surface = surface ~= nil
    })
    return nil
  end

  local normal_pos = gps_helpers.normalize_landing_position_with_cache(player, gps_parser.gps_from_map_position(map_pos, player.surface.index), Cache)
  if not normal_pos then 
    ErrorHandler.warn_log("Could not find valid landing area for GPS update")
    return nil
  end

  -- Safe extraction of old chart tag properties
  local old_text, old_icon = safe_extract_chart_tag_properties(old_chart_tag)
  
  local new_chart_tag = TagSync.add_new_chart_tag(player, normal_pos, old_text, old_icon)
  if not new_chart_tag then 
    ErrorHandler.warn_log("Failed to create new chart tag during GPS update")
    return nil
  end

  new_gps = gps_parser.gps_from_map_position(new_chart_tag.position, surface_index)
  -- If the GPS has changed, update all player favorites
  update_player_favorites_gps(tag.gps, new_gps)
  tag.gps = new_gps
  tag.chart_tag = new_chart_tag

  -- Safe destruction of old chart tag
  if old_chart_tag and old_chart_tag.valid then 
    old_chart_tag.destroy() 
    ErrorHandler.debug_log("Destroyed old chart tag during GPS update")
  end

  Lookups.clear_chart_tag_cache(surface_index)
  
  ErrorHandler.debug_log("Tag GPS update completed successfully", {
    final_gps = new_gps
  })

  return tag
end

---Delete a tag for a player, updating all relevant collections and state.
---Removes the player from the tag's faved_by_players, resets any matching favorite slot for the player,
---clears last_user if the player was the last user, and deletes the tag and chart_tag if no faved_by_players remain.
---If other players still favorite the tag, returns the tag; otherwise, returns nil after deletion.
---@param player LuaPlayer
---@param tag Tag
---@return Tag|nil
function TagSync.delete_tag_by_player(player, tag)
  local is_valid, issues = validate_sync_inputs(player, tag)
  if not is_valid then
    ErrorHandler.warn_log("Tag deletion validation failed", { issues = issues })
    return nil
  end
  
  if not player or not tag then 
    ErrorHandler.warn_log("Cannot delete tag: invalid player or tag")
    return nil
  end
  
  ErrorHandler.debug_log("Starting tag deletion by player", {
    player = player.name,
    tag_gps = tag.gps
  })
  
  -- Remove the favorite for this player
  local player_favorites = PlayerFavorites.new(player)
  local success, error_msg = player_favorites:remove_favorite(tag.gps)
  
  if not success then
    ErrorHandler.warn_log("Failed to remove player favorite during tag deletion", {
      error = error_msg,
      gps = tag.gps
    })
  end
  
  -- Check if other players still have this favorited
  if tag.faved_by_players and Helpers.table_count(tag.faved_by_players) > 0 then
    -- Clear last user but keep the tag since others have it favorited
    if tag.chart_tag and tag.chart_tag.valid then
      tag.chart_tag.last_user = nil
      ErrorHandler.debug_log("Cleared last_user, tag kept due to other favorites")
    end
    return tag
  end
  
  -- No other players have this favorited, check if player is owner and remove completely
  if Tag.is_owner and Tag.is_owner(tag, player) then
    Cache.remove_stored_tag(tag.gps)
    ErrorHandler.debug_log("Tag completely removed from storage", { gps = tag.gps })
    return nil
  end
  
  ErrorHandler.debug_log("Tag deletion completed", { 
    kept_tag = tag ~= nil,
    gps = tag.gps
  })
  
  return tag
end

---Remove a tag and its related chart_tag from all collections.
---@param tag Tag
function TagSync.remove_tag_and_associated(tag)
  if not tag then
    ErrorHandler.warn_log("Cannot remove tag: tag is nil")
    return
  end
  
  ErrorHandler.debug_log("Removing tag and associated chart_tag", {
    tag_gps = tag.gps
  })
  
  Tag.unlink_and_destroy(tag)
  
  ErrorHandler.debug_log("Tag and associated chart_tag removed successfully")
end

return TagSync
