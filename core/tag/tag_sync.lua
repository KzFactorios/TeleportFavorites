---@diagnostic disable: undefined-global
local Tag = require("core.tag.tag")
local GPS = require("core.gps.gps")
local Cache = require("core.cache.cache")
local PlayerFavorites = require("core.favorite.player_favorites")
local Favorite = require("core.favorite.favorite")

---@class TagSync
local TagSync = {}
TagSync.__index = nil -- No instance methods, only static

--- Ensure a chart_tag exists for a given Tag, creating one if needed
---@param player LuaPlayer
---@param tag Tag
---@return LuaCustomChartTag?  -- Factorio returns LuaCustomChartTag
function TagSync.guarantee_chart_tag(player, tag)
  if not player then return nil end
  local chart_tag = tag.chart_tag
  if chart_tag and chart_tag.valid then return chart_tag end

  local icon = chart_tag and chart_tag.icon or {}
  local text = chart_tag and chart_tag.text or ""
  local map_pos = GPS.map_position_from_gps(tag.gps)
  local surface_index = GPS.get_surface_index(tag.gps)
  local surface = game.surfaces[surface_index]

  if not map_pos or not surface_index then
    error("Invalid GPS string: " .. tostring(tag.gps))
  end
  if not surface then
    error("Surface not found for tag.gps: " .. tag.gps)
  end

  -- align_position_for_landing
  local chart_tag_spec = {
    position = GPS.map_position_from_gps(tag.gps),
    text = text,
    icon = icon,
    last_user = player.name
  }

  local chart_tag_obj = game.forces["player"]:add_chart_tag(surface, chart_tag_spec)
  if not chart_tag_obj then
    error("Matching chart tag could not be created: " .. tostring(tag.gps))
  end
  -- cleanup
  if chart_tag ~= nil then chart_tag.destroy() end

  tag.chart_tag = chart_tag_obj -- LuaEntity
  return chart_tag_obj
end

--- Remove a tag and its related chart_tag from all collections
---@param tag Tag
function TagSync.remove_tag_and_chart_tag(tag)
  local old_gps = tag.gps
  local surface_index = GPS.get_surface_index(tag.gps) or 1
  local surface_data = Cache.get_surface_data(surface_index)

   -- delete/reset any player_favorites that match the gps
  for _, player in pairs(game.players) do
    local faves = PlayerFavorites.get_player_favorites(player)
    for _, fave in pairs(faves) do
      if fave.gps == tag.gps then
        fave.gps = ""
        fave.locked = false
      end
    end
  end
  
  local chart_tag = tag.chart_tag
  if chart_tag and chart_tag.valid then
    chart_tag.destroy()
  end

  ---@diagnostic disable-next-line
  if surface_data then
    if not surface_data.tags then surface_data.tags = {} end
    surface_data.tags[tag.gps] = nil
  end
end

--- Delete a tag for a player, updating all relevant collections and state.
--- Removes the player from the tag's faved_by_players, resets the favorite slot for the player,
--- clears last_user if the player was the last user, and deletes the tag and chart_tag if no faved_by_players players remain.
--- If other players still favorite the tag, returns the tag; otherwise, returns nil after deletion.
---@param player LuaPlayer The player removing the tag
---@param tag Tag The tag to be deleted
---@return Tag|nil Returns the tag if it is still favorited by others, or nil if deleted
function TagSync.delete_tag_by_player(player, tag)
  -- Remove the player.index from faved_by_players
  local faved_by_players = tag.faved_by_players or {}
  local new_faved = {}
  for _, idx in ipairs(faved_by_players) do
    if idx ~= player.index then
      table.insert(new_faved, idx)
    end
  end
  tag.faved_by_players = new_faved

  -- Remove the favorite from the player's favorites for the surface (reset the slot to a Favorite.blank_favorite)
  local player_favs = PlayerFavorites.new(player)
  for i, fav in ipairs(player_favs.favorites) do
    if fav.gps == tag.gps then
      ---@diagnostic disable-next-line: assign-type-mismatch
      player_favs.favorites[i] = Favorite.get_blank_favorite()
    end
  end

  -- If tag.chart_tag.last_user == player.name, then set the tag.chart_tag.last_user = nil
  if tag.chart_tag and tag.chart_tag.last_user == player.name then
    tag.chart_tag.last_user = nil
  end

  -- If other players have favorited this tag, it will not be deleted and the tag should be returned
  if #tag.faved_by_players > 0 then
    return tag
  end

  -- Otherwise, destroy the chart_tag and remove the tag from storage, then return nil
  if tag.chart_tag and tag.chart_tag.valid then
    tag.chart_tag:destroy()
  end
  -- Remove tag from persistent storage
  local surface_index = GPS.get_surface_index(tag.gps) or player.surface.index or 1
  surface_index = tonumber(surface_index) or 1
  local surface_data = Cache.get_surface_data(surface_index)
  if type(surface_data) == "table" and type(surface_data.tags) == "table" then
    surface_data.tags[tag.gps] = nil
  end
  return nil
end

return TagSync
