---@diagnostic disable: undefined-global
local Tag = require("core.tag.tag")
local TagSync = require("core.tag.tag_sync")
local GPS = require("core.gps.gps")
local Lookups = require("core.cache.lookups")
local PlayerFavorites = require("core.favorite.player_favorites")
local Favorite = require("core.favorite.favorite")

---@class TagSync
local TagSync = {}
TagSync.__index = nil -- No instance methods, only static


local function get_cache()
  return require("core.cache.cache")
end

local function get_player_favorites(player)
  return get_cache().get_player_favorites(player, player.surface)
end

---@param old_gps string
---@param new_gps string
local function update_player_favorites_gps(old_gps, new_gps)
  for _, player in pairs(game.players) do
    local faves = get_player_favorites(player)
    for _, fave in pairs(faves) do
      if fave.gps == old_gps then
        fave.gps = new_gps
      end
    end
  end
end

---@param player LuaPlayer
---@param normal_pos MapPosition
---@param text string
---@param icon SignalID
---@return LuaCustomChartTag?
function TagSync.add_new_chart_tag(player, normal_pos, text, icon)
  local chart_tag_spec = {
    position = normal_pos,
    text = text,
    icon = icon,
    last_user = player_name
  }

  local new_chart_tag = game.forces["player"]:add_chart_tag(player.surface, chart_tag_spec)
  return new_chart_tag
end

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

  -- normalize_landing_position
  local msg, normal_pos = GPS.normalize_landing_position(player, tag)
  if msg ~= nil and Helpers.trim(msg) ~= "" then
    error(msg .. tag.gps)
  end
  if not normal_pos then
    error("Sorry, we couldn't find a valid landing area. Try another location")
  end

  -- create new chart_tag at position
  local new_chart_tag = TagSync.add_new_chart_tag(player, normal_pos, text, icon)
  if not new_chart_tag then
    error("Sorry, we couldn't find a valid landing area. Try another location")
  end

  -- update any related favorites
  local new_gps = GPS.gps_from_map_position(new_chart_tag.position, surface_index)
  update_player_favorites_gps(tag.gps, new_gps)

  -- cleanup
  if chart_tag ~= nil then chart_tag.destroy() end
  tag.chart_tag = new_chart_tag -- LuaEntity
  tag.gps = new_gps
  return new_chart_tag
end

--- FOR ALL PLAYERS delete/reset any player_favorites that match the gps
---@param tag Tag
local function remove_all_player_favorites_by_tag(tag)
  for _, player in pairs(game.players) do
    local faves = get_player_favorites(player)
    for _, fave in pairs(faves) do
      if fave.gps == tag.gps then
        fave.gps = ""
        fave.locked = false
        Tag:remove_faved_by_player(player.index)
      end
    end
  end
end

---@param tag Tag
local function remove_chart_tag_by_tag(tag)
  local chart_tag = tag.chart_tag
  if chart_tag and chart_tag.valid then
    chart_tag.destroy()
  end
end

---@param gps string
local function remove_tag_from_storage(gps)
  local surface_index = GPS.get_surface_index(gps) or 1 -- ensure integer
  local surface_data = Cache.get_surface_data(surface_index)
  ---@diagnostic disable-next-line
  if surface_data then
    if not surface_data.tags then surface_data.tags = {} end
    surface_data.tags[gps] = nil
  end
end

--- Remove a tag and its related chart_tag from all collections
---@param tag Tag
function TagSync.remove_tag_and_associated(tag)
  Tag.unlink_and_destroy(tag)
end

--- Update a tag's GPS and associated chart_tag, destroying the old chart_tag
---@param player LuaPlayer
---@param tag Tag
---@param new_gps string
function TagSync.update_tag_gps_and_associated(player, tag, new_gps)
  if tag == nil or tag.gps == new_gps then return end

  local old_chart_tag = tag.chart_tag
  local surface_index = GPS.get_surface_index(new_gps) or player.surface.index or 1

  -- verify and normalize the new location
  local msg, normal_pos = GPS.normalize_landing_position(player, GPS.map_position_from_gps(new_gps), surface_index)
  if msg ~= nil and Helpers.trim(msg) ~= "" then
    error(msg .. tag.gps)
  end
  if not normal_pos then
    error("Sorry, we couldn't find a valid landing area. Try another location")
  end

  --create the new and delete the old
  local new_chart_tag = TagSync.add_new_chart_tag(player, normal_pos, tag.chart_tag.text, tag.chart_tag.icon)
  if not new_chart_tag then
    error("Sorry, we couldn't find a valid landing area. Try another location")
  end

  -- update player favorites to use the new gps
  update_player_favorites_gps(tag.gps, GPS.gps_from_map_position(normal_pos, surface_index))
  tag.chart_tag = new_chart_tag
  if old_chart_tag and old_chart_tag.valid then
    old_chart_tag:destroy()
  end
  Lookups.clear_chart_tag_cache(surface_index)
end

--- Delete a tag for a player, updating all relevant collections and state.
--- Removes the player from the tag's faved_by_players, resets any matching favorite slot for the player,
--- clears last_user if the player was the last user, and deletes the tag and chart_tag if no faved_by_players 
--- player indices remain.
--- If other players still favorite the tag, returns the tag; otherwise, returns nil after deletion.
---@param player LuaPlayer The player removing the tag
---@param tag Tag The tag to be deleted
---@return Tag|nil Returns the tag if it is still favorited by others, or nil if deleted
function TagSync.delete_tag_by_player(player, tag)
  if not player or not tag then return end

-- remove player index from faved_by_players
    PlayerFavorites:remove_favorite( tag.gps)

    -- if tag faved_by_Players then we will not delete the chart_tag and update last_user to nil
    if Helpers.table_count(tag.faved_by_players) > 0 then
      tag.chart_tag.last_user = nil
      return tag
    end

    if Tag:is_owner(player) then
      -- we have full permission to delete
      Cache.remove_stored_tag(tag.gps)
    end
  return tag or nil
end

return TagSync
