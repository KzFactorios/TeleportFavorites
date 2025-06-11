--[[
TeleportFavorites - TagSync Module

This module provides static functions for synchronizing, updating, and removing chart tags and their associated favorites across all players. It ensures tag consistency, handles GPS normalization, and manages tag/favorite relationships robustly. All major tag and chart_tag operations are centralized here for maintainability and DRYness.
--]]
---@diagnostic disable: undefined-global
local Tag = require("core.tag.tag")
local TagSync = require("core.tag.tag_sync")
local GPS = require("core.gps.gps")
local gps_helpers = require("core.utils.gps_helpers")
local PlayerFavorites = require("core.favorite.player_favorites")
local Helpers = require("core.utils.basic_helpers")
local Cache = require("core.cache.cache")
local Lookups = Cache.lookups

---Update every players' favorites, replacing old_gps with new_gps, because it is possible for
--- multiple players to have the same GPS in their favorites.
---@param old_gps string
---@param new_gps string
local function update_player_favorites_gps(old_gps, new_gps)
  for _, player in pairs(game.players) do
    local pfaves = Cache.get_player_favorites(player)
    for _, fave in pairs(pfaves) do
      if fave.gps == old_gps then fave.gps = new_gps end
    end
  end
end

---Add a new chart tag for a player at a normalized position.
---@param player LuaPlayer
---@param normal_pos MapPosition
---@param text string
---@param icon SignalID
---@return LuaCustomChartTag?
function TagSync.add_new_chart_tag(player, normal_pos, text, icon)
  return game.forces["player"]:add_chart_tag(player.surface, {
    position = normal_pos, text = text, icon = icon, last_user = player_name
  })
end

---Ensure a chart_tag exists for a given Tag, creating one if needed.
---@param player LuaPlayer
---@param tag Tag
---@return LuaCustomChartTag?
function TagSync.guarantee_chart_tag(player, tag)
  if not player then return nil end

  local chart_tag = tag.chart_tag
  if chart_tag and chart_tag.valid then return chart_tag end

  local icon, text = chart_tag and chart_tag.icon or {}, chart_tag and chart_tag.text or ""
  local map_pos, surface_index = GPS.map_position_from_gps(tag.gps), GPS.get_surface_index(tag.gps)
  local surface = game.surfaces[surface_index]

  if not map_pos or not surface_index then error("Invalid GPS string: " .. tostring(tag.gps)) end
  if not surface then error("Surface not found for tag.gps: " .. tag.gps) end

  local normal_pos = gps_helpers.normalize_landing_position(player, GPS.gps_from_map_position(map_pos, player.surface.index))
  if not normal_pos then error("Sorry, we couldn't find a valid landing area. Try another location") end

  local new_chart_tag = TagSync.add_new_chart_tag(player, normal_pos, text, icon)
  if not new_chart_tag then error("Sorry, we couldn't find a valid landing area. Try another location") end

  local new_gps = GPS.gps_from_map_position(new_chart_tag.position, surface_index)
  if new_gps ~= tag.gps then
    -- If the GPS has changed, update all player favorites
    update_player_favorites_gps(tag.gps, new_gps)
    tag.gps = new_gps
  end

  -- dispose of the working chart_tag
  if chart_tag and chart_tag.valid then chart_tag.destroy() end
  tag.chart_tag = new_chart_tag
  Cache.lookups.clear_chart_tag_cache(surface.index)

  return tag.chart_tag
end

---Update a tag's GPS and associated chart_tag, destroying the old chart_tag.
---@param player LuaPlayer
---@param tag Tag
---@param new_gps string
---@return Tag|nil
function TagSync.update_tag_gps_and_associated(player, tag, new_gps)
  if not tag or tag.gps == new_gps then return end

  local old_gps = tag.gps
  local old_chart_tag = tag.chart_tag
  local surface_index = GPS.get_surface_index(new_gps) or player.surface.index or 1
  local map_pos = GPS.map_position_from_gps(new_gps)
  local surface = game.surfaces[surface_index]

  if not map_pos or not surface then error("Invalid GPS or surface for update.") end

  local normal_pos = gps_helpers.normalize_landing_position(player, GPS.gps_from_map_position(map_pos, player.surface.index))
  if not normal_pos then error("Sorry, we couldn't find a valid landing area. Try another location") end

  local new_chart_tag = TagSync.add_new_chart_tag(player, normal_pos, old_chart_tag.text, old_chart_tag.icon)
  if not new_chart_tag then error("Sorry, we couldn't find a valid landing area. Try another location") end

  new_gps = GPS.gps_from_map_position(new_chart_tag.position, surface_index)
  -- If the GPS has changed, update all player favorites
  update_player_favorites_gps(tag.gps, new_gps)
  tag.gps = new_gps
  tag.chart_tag = new_chart_tag

  if old_chart_tag.valid then old_chart_tag.destroy() end

  Lookups.clear_chart_tag_cache(surface_index)

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
  if not player or not tag then return end
  PlayerFavorites:remove_favorite(tag.gps)
  if Helpers.table_count(tag.faved_by_players) > 0 then
    tag.chart_tag.last_user = nil
    return tag
  end
  if Tag:is_owner(player) then Cache.remove_stored_tag(tag.gps) end
  return tag or nil
end

---Remove all player favorites that match the tag's GPS.
---@param tag Tag
local function remove_all_player_favorites_by_tag(tag)
  for _, player in pairs(game.players) do
    local pfaves = Cache.get_player_favorites(player)
    for _, fave in pairs(pfaves) do
      if fave.gps == tag.gps then
        fave.gps, fave.locked = "", false
        Tag:remove_faved_by_player(player.index)
      end
    end
  end
end

---Remove a tag from storage by GPS.
---@param gps string
local function remove_tag_from_storage(gps)
  local surface_index = GPS.get_surface_index(gps) or 1
  local surface_data = Cache.get_surface_data(surface_index)
  surface_data.tags = surface_data.tags or {}
  surface_data.tags[gps] = nil
end

---Remove a tag and its related chart_tag from all collections.
---@param tag Tag
function TagSync.remove_tag_and_associated(tag)
  Tag.unlink_and_destroy(tag)
end

return TagSync
