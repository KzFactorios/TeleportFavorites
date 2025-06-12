--[[
core/tag/tag.lua
TeleportFavorites Factorio Mod
-----------------------------
Tag model and utilities for managing teleportation tags, chart tags, and player favorites.

- Encapsulates tag data (GPS, chart_tag, faved_by_players) and provides methods for favorite management, ownership checks, and tag rehoming.
- Handles robust teleportation logic with error messaging, including vehicle and collision checks.
- Provides helpers for moving, destroying, and unlinking tags and their associated chart tags.
- All tag-related state and operations are centralized here for maintainability and DRYness.
]]

local Constants = require("constants")
local Favorite = require("core.favorite.favorite")
local Settings = require("settings")
local helpers = require("core.utils.helpers_suite")
local GPS = require("core.gps.gps")
local basic_helpers = require("core.utils.basic_helpers")
local gps_helpers = require("core.utils.gps_helpers")
local tag_destroy_helper = require("core.tag.tag_destroy_helper")
local Lookups = require("core.cache.lookups")
local Cache = require("core.cache.cache")

---@class Tag
---@field gps string # The GPS string (serves as the index)
---@field chart_tag LuaCustomChartTag # Cached chart tag (private)
---@field faved_by_players uint[] # Array of player indices who have favorited this tag
local Tag = {}
Tag.__index = Tag

local destroying_tags = setmetatable({}, { __mode = "k" })
local destroying_chart_tags = setmetatable({}, { __mode = "k" })

--- Create a new Tag instance.
---@param gps string
---@param faved_by_players uint[]|nil
---@return Tag
function Tag.new(gps, faved_by_players)
  return setmetatable({ gps = gps, faved_by_players = faved_by_players or {} }, Tag)
end

--- Get and cache the related LuaCustomChartTag by gps.
---@return LuaCustomChartTag|nil
function Tag:get_chart_tag()
  self.chart_tag = self.chart_tag or Lookups.get_chart_tag_by_gps(self.gps)
  return self.chart_tag
end

--- Check if the player is the owner (last_user) of this tag.
---@param player LuaPlayer
---@return boolean
function Tag:is_owner(player)
  return self.chart_tag and player and player.name and self.chart_tag.last_user == player.name or false
end

--- Add a player index to faved_by_players if not present using functional approach.
---@param player_index uint
function Tag:add_faved_by_player(player_index)
  assert(type(player_index) == "number", "player_index must be a number")

  -- Use functional approach to check if player already exists
  local function player_exists(idx)
    return idx == player_index
  end

  if not helpers.find_first_match(self.faved_by_players, player_exists) then
    table.insert(self.faved_by_players, player_index)
  end
end

--- Remove a player index from faved_by_players using functional approach.
---@param player_index uint
function Tag:remove_faved_by_player(player_index)
  -- Use functional table_remove_value helper
  helpers.table_remove_value(self.faved_by_players, player_index)
end

--- Teleport a player to a position on a surface, with robust checks and error messaging.
---@param player LuaPlayer
---@param gps string
---@return string|integer
function Tag.teleport_player_with_messaging(player, gps)
  if not player or not player.valid then return "Unable to teleport. Player is missing" end
  if rawget(player, "character") == nil then return "Unable to teleport. Player character is missing" end
  --local teleport_map_position = GPS.map_position_from_gps(gps)

  local aligned_position = GPS.normalize_landing_position_with_cache(player, gps, Cache)
  if not aligned_position then
    player:print("Unable to normalize landing position")
    return
  end

  local teleport_AOK = false
  local raise_teleported = true

  if player.driving and player.vehicle then
    if _G.defines and player.riding_state and player.riding_state ~= _G.defines.riding.acceleration.nothing then
      return player:print("Are you crazy? Trying to teleport while driving is strictly prohibited.")
    end
    player.vehicle:teleport(aligned_position, player.surface, not raise_teleported)
    teleport_AOK = player:teleport(aligned_position, player.surface, raise_teleported)
  else
    teleport_AOK = player:teleport(aligned_position, player.surface, raise_teleported)
  end

  if teleport_AOK then return Constants.enums.return_state.SUCCESS end

  return "We were unable to perform the teleport due to unforeseen circumstances"
end

--- Unlink and destroy a tag and its associated chart_tag, and remove from all collections.
---@param tag Tag
function Tag.unlink_and_destroy(tag)
  if not tag or not tag.gps then return end
  tag_destroy_helper.destroy_tag_and_chart_tag(tag, tag.chart_tag)
end

--- Move a chart_tag to a new location, updating all favorites and destroying the old tag.
---@param player LuaPlayer
---@param chart_tag LuaCustomChartTag
---@param destination_gps string this location needs to be verified/snapped/etc. This function assumes the dest has been OK'd
---@return LuaCustomChartTag|nil
function Tag.rehome_chart_tag(player, chart_tag, destination_gps)
  local current_gps = gps_helpers.gps_from_map_position(chart_tag.position)
  if current_gps == destination_gps then return chart_tag end

  local destination_pos = GPS.map_position_from_gps(destination_gps)
  if not destination_pos then return error("There was a problem with the new coordinates") end

  -- get potentially linked faves from all players
  local all_fave_tags = {}
  local game_players = (_G.game and _G.game.players) or {}
  for _, a_player in pairs(game_players) do
    local pfaves = Cache.get_player_favorites(a_player)
    for _, favorite in pairs(pfaves) do
      if favorite.gps == current_gps then table.insert(all_fave_tags, favorite) end
    end
  end

  -- Use "character" entity with adjusted parameters for reliable collision detection
  -- Character entity is guaranteed to be available in all Factorio configurations
  -- Increased radius provides safety margin similar to car collision box size
  local safety_radius = Settings.get_player_settings(player).teleport_radius + 2  -- Add safety margin for vehicle-sized clearance  
  local fine_precision = Constants.settings.TELEPORT_PRECISION * 0.5 -- Finer search precision

  local non_collide_position = nil
  local success, error_msg = pcall(function()
    non_collide_position = player.surface:find_non_colliding_position("character", destination_pos,
      safety_radius, fine_precision)
  end)
  if not non_collide_position then
    return error("There was a problem with the new coordinates. The destination is not available for landing")
  end

  -- normalize the landing position
  -- check for tiles/validity
  local x = basic_helpers.normalize_index(non_collide_position.position.x)
  local y = basic_helpers.normalize_index(non_collide_position.position.y)

  if not gps_helpers.position_can_be_tagged(player, { x = x, y = y }) then
    return error("There was a problem with the new coordinates. The destination is not available for landing")
  end

  -- use the normaled position
  destination_pos = { x = x, y = y }
  destination_gps = gps_helpers.gps_from_map_position(destination_pos)

  local chart_tag_spec = {
    position = destination_pos,
    icon = chart_tag.icon,
    text = chart_tag.text,
    last_user = chart_tag.last_user or player.name
  }

  local new_chart_tag = player.force:add_chart_tag(player.surface, chart_tag_spec)
  if not gps_helpers.position_can_be_tagged(player, new_chart_tag.position) then
    new_chart_tag.destroy()
    new_chart_tag = nil
  end
  if not new_chart_tag or not new_chart_tag.valid then return error("There was a problem with the new coordinates. The destination is not available for landing") end

  -- ensure matching tag has updated gps - refresh collection
  local matching_tag = Cache.get_tag_by_gps(current_gps)
  if matching_tag then matching_tag.gps = destination_gps end

  for _, favorite in pairs(all_fave_tags) do
    favorite.gps = destination_gps
  end

  -- get rid of the old chart_tag to make way for the new
  if chart_tag and chart_tag.valid then chart_tag.destroy() end

  return new_chart_tag
end

return Tag
