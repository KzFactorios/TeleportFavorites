--[[
game_helpers.lua
TeleportFavorites Factorio Mod
-----------------------------
Game-specific utilities: teleport, sound, space/water detection, tag collision, etc.
Extracted from helpers_suite.lua for better organization and maintainability.
]]

local Constants = require("constants")
local Settings = require("settings")

---@class GameHelpers
local GameHelpers = {}

function GameHelpers.is_on_space_platform(player)
  if not player or not player.surface or not player.surface.name then return false end
  local name = player.surface.name:lower()
  return name:find("space") ~= nil or name == "space-platform"
end

--- Finds the nearest chart tag to a clicked position within a specified radius
-- @param player LuaPlayer The player whose force and surface will be used
-- @param map_position table The map position to search around {x=number, y=number}
-- @param search_radius Optional explicit search radius (falls back to player settings if nil)
-- @return The nearest chart tag or nil if none found
function GameHelpers.get_nearest_tag_to_click_position(player, map_position, search_radius)
  if not player then return nil end
  
  -- Use provided search_radius if available, otherwise fall back to player settings
  local collision_radius = search_radius
  if not collision_radius then
    local player_settings = Settings:getPlayerSettings(player)
    collision_radius = player_settings.teleport_radius or Constants.settings.TELEPORT_RADIUS_DEFAULT
  end
    -- Create collision detection area centered on the map position
  -- Small buffer (0.1) ensures we don't include tags exactly on the boundary
  local collision_area = {
    left_top = { x = map_position.x - collision_radius + 0.1, y = map_position.y - collision_radius + 0.1 },
    right_bottom = { x = map_position.x + collision_radius - 0.1, y = map_position.y + collision_radius - 0.1 }
  }
  
  local colliding_tags = player.force.find_chart_tags(player.surface, collision_area)
  if colliding_tags and #colliding_tags > 0 then return colliding_tags[1] end
  
    return nil
end

function GameHelpers.is_water_tile(surface, pos)
  if not surface or not surface.get_tile then return false end
  local tile = surface.get_tile(math.floor(pos.x), math.floor(pos.y))
  if tile and tile.prototype and tile.prototype.collision_mask then
    for _, mask in pairs(tile.prototype.collision_mask) do
      if mask == "water-tile" then return true end
    end
  end
  return false
end

function GameHelpers.is_space_tile(surface, pos)
  if not surface or not surface.get_tile then return false end
  local tile = surface.get_tile(math.floor(pos.x), math.floor(pos.y))
  if tile and tile.prototype and tile.prototype.collision_mask then
    for _, mask in pairs(tile.prototype.collision_mask) do
      if mask == "space" then return true end
    end
  end
  return false
end

function GameHelpers.safe_teleport(player, pos)
  if player and player.valid then
    if pos.x and pos.y then return player.teleport({ x = pos.x, y = pos.y }, player.surface) end
    if pos[1] and pos[2] then return player.teleport({ x = pos[1], y = pos[2] }, player.surface) end
  end
  return false
end

function GameHelpers.safe_play_sound(player, sound)
  if player and player.valid and type(player.play_sound) == "function" and type(sound) == "table" then
    pcall(function() player.play_sound(sound, {}) end)
  end
end

-- Player print (already present, but ensure DRY)
function GameHelpers.player_print(player, message)
  if player and player.valid and type(player.print) == "function" then player.print(message) end
end

-- Tag/favorite state update logic
function GameHelpers.update_favorite_state(player, tag, is_favorite, PlayerFavorites)
  -- PlayerFavorites is required to avoid circular require
  if not PlayerFavorites or not player or not tag then return end
  local pfaves = PlayerFavorites.new(player)
  if is_favorite then
    pfaves:add_favorite(tag.gps)
  else
    pfaves:remove_favorite(tag.gps)
  end
end

function GameHelpers.update_tag_chart_fields(tag, text, icon, player)
  tag.chart_tag = tag.chart_tag or {}
  tag.chart_tag.text = text
  tag.chart_tag.icon = icon
  tag.chart_tag.last_user = (not tag.chart_tag.last_user or tag.chart_tag.last_user == "") and player.name or
      tag.chart_tag.last_user
end

function GameHelpers.update_tag_position(tag, pos, gps)
  tag.chart_tag = tag.chart_tag or {}
  tag.chart_tag.position = pos
  tag.gps = gps
end

return GameHelpers
