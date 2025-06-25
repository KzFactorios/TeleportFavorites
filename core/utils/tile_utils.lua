--[[
tile_utils.lua
TeleportFavorites Factorio Mod
-----------------------------
A utility module for tile-related functions to break circular dependencies.
This module is imported by teleport_strategy.lua but has no other dependencies.
]]

local TileUtils = {}

--- Check if a tile at a position is a water tile
---@param surface LuaSurface Surface to check
---@param position MapPosition Position to check
---@return boolean is_water_tile
function TileUtils.is_water_tile_at_position(surface, position)
  if not surface or not surface.get_tile or not position then return false end
  local norm_pos = require("core.utils.position_utils").normalize_position(position)
  local tile = surface.get_tile(norm_pos.x, norm_pos.y)
  if not tile or not tile.valid then return false end
  local tile_name = tile.name:lower()
  return tile_name:find("water") ~= nil
end

--- Check if a position appears walkable (not water/space)
---@param surface LuaSurface
---@param position MapPosition
---@return boolean appears_walkable
function TileUtils.appears_walkable(surface, position)
  if not surface or not surface.get_tile or not position then return false end
  local norm_pos = require("core.utils.position_utils").normalize_position(position)
  local tile = surface.get_tile(norm_pos.x, norm_pos.y)
  if not tile or not tile.valid then return false end
  local tile_name = tile.name:lower()
  -- Simple check for obviously non-walkable tiles
  if tile_name:find("water") or tile_name:find("space") or tile_name:find("void") then
    return false
  end
  return true
end

--- Find safe landing position near a potentially unsafe tile (like water)
---@param surface LuaSurface Surface to search on
---@param position MapPosition Original position
---@param search_radius number? Search radius (default: 16.0)
---@param precision number? Search precision (default: 0.5)
---@return MapPosition? safe_position Safe position or nil if none found
function TileUtils.find_safe_landing_position(surface, position, search_radius, precision)
  if not surface or not position then return nil end
  
  search_radius = search_radius or 16.0
  precision = precision or 0.5
  
  -- Use Factorio's built-in collision detection to find a safe position
  return surface.find_non_colliding_position("character", position, search_radius, precision)
end

return TileUtils
