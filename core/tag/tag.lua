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

--- Check if a player has favorited this tag using functional approach.
---@param player LuaPlayer
---@return boolean
function Tag:is_player_favorite(player)
  if not self or not self.faved_by_players or not player or not player.index then return false end
  
  -- Use functional approach to check if player index exists
  local function player_index_matcher(idx)
    return idx == player.index
  end
  
  return helpers.find_first_match(self.faved_by_players, player_index_matcher) ~= nil
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

  local aligned_position = GPS.normalize_landing_position(player, gps, Cache)
  if not aligned_position then player:print("Unable to normalize landing position") return end

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

--- Move a chart_tag to a new location, updating all favorites and destroying the old tag.
---@param player LuaPlayer
---@param destination_gps string
---@return string|nil, LuaCustomChartTag|nil
function Tag:rehome_chart_tag(player, destination_gps)
  if not self or not self.gps then return "Invalid tag object" end
  local current_gps = self.gps  local destination_pos = GPS.map_position_from_gps(destination_gps)
  if not destination_pos then return "[TeleportFavorites] Could not parse destination GPS string" end
  local aligned_position = GPS.normalize_landing_position(player, destination_gps, Cache)
  if not aligned_position then return "[TeleportFavorites] Could not find a valid location within range" end

  local surface_index = player.surface and player.surface.index or 1
  local aligned_gps = GPS.gps_from_map_position(aligned_position, surface_index)
  local old_chart_tag = self:get_chart_tag()
  if current_gps == aligned_gps and old_chart_tag and old_chart_tag.valid == true then return nil, old_chart_tag end

  local all_fave_tags = {}
  local game_players = (_G.game and _G.game.players) or {}
  for _, other_player in pairs(game_players) do
    local pfaves = Cache.get_player_favorites(other_player)
    for _, favorite in pairs(pfaves) do
      if favorite.gps == current_gps then table.insert(all_fave_tags, favorite) end
    end
  end
  local chart_tag_spec = {
    position = aligned_position,
    icon = old_chart_tag and old_chart_tag.icon or {},
    text = old_chart_tag and old_chart_tag.text or "",
    last_user = old_chart_tag and old_chart_tag.last_user or player.name
  }
  local surface = player.surface
  local new_chart_tag = player.force:add_chart_tag(surface, chart_tag_spec)
  if not new_chart_tag or not new_chart_tag.valid then return "Failed to create new chart tag" end
  for _, favorite in pairs(all_fave_tags) do favorite.gps = aligned_gps end
  self.gps, self.chart_tag = aligned_gps, new_chart_tag
  if old_chart_tag and old_chart_tag.valid then tag_destroy_helper.destroy_tag_and_chart_tag(nil, old_chart_tag) end
  return nil, self.chart_tag
end

--- Unlink and destroy a tag and its associated chart_tag, and remove from all collections.
---@param tag Tag
function Tag.unlink_and_destroy(tag)
  if not tag or not tag.gps then return end
  tag_destroy_helper.destroy_tag_and_chart_tag(tag, tag.chart_tag)
end

return Tag
