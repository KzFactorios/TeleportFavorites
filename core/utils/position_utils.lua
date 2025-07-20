---@diagnostic disable: undefined-global, param-type-mismatch

-- Includes position validation, normalization, correction, tagging checks, water/space detection, safe landing, and walkability.

local basic_helpers = require("core.utils.basic_helpers")
local ErrorHandler = require("core.utils.error_handler")
local Logger = require("core.utils.error_handler")

---@class PositionUtils
local PositionUtils = {}

--- Normalize a map position to whole numbers if needed
--- Handles both array-style [x, y] and object-style {x = ..., y = ...} positions
---@param map_position MapPosition
---@return MapPosition|nil normalized_position
function PositionUtils.normalize_position(map_position)
  if not map_position then return nil end
  local x, y
    if type(map_position) == "table" then
      if map_position.x ~= nil and map_position.y ~= nil then
        x, y = map_position.x, map_position.y
      elseif type(map_position[1]) == "number" and type(map_position[2]) == "number" then
        x, y = map_position[1], map_position[2]
      else
        return nil
      end
      if x == nil or y == nil then return nil end
      if basic_helpers.is_whole_number(x) and basic_helpers.is_whole_number(y) then
        return {x = x, y = y}
      end
      return {x = math.floor(x), y = math.floor(y)}
    end
    return nil
end

-- core/utils/position_utils.lua
-- TeleportFavorites Factorio Mod
-- Consolidated position utilities for all position-related functionality.
--- Check if a map position needs normalization (x or y not whole number)
---@param map_position MapPosition
---@return boolean needs_norm
function PositionUtils.needs_normalization(map_position)
  if not map_position then return false end
  local x, y
  if type(map_position) == "table" then
    if map_position.x ~= nil and map_position.y ~= nil then
      x, y = map_position.x, map_position.y
    elseif type(map_position[1]) == "number" and type(map_position[2]) == "number" then
      x, y = map_position[1], map_position[2]
    else
      return false
    end
    if x == nil or y == nil then return false end
    return not (basic_helpers.is_whole_number(x) and basic_helpers.is_whole_number(y))
  end
  return false
end

--- Create old/new position pair for tracking position changes
---@param position MapPosition
---@return table {old: MapPosition, new: MapPosition}
function PositionUtils.create_position_pair(position)
  return {
    old = { x = position.x, y = position.y },
    new = {
      x = basic_helpers.normalize_index(position.x),
      y = basic_helpers.normalize_index(position.y)
    }
  }
end

--- Check if a tile at a position is water
--- Consolidated from multiple implementations across the codebase
---@param surface LuaSurface
---@param position MapPosition
---@return boolean is_water
function PositionUtils.is_water_tile(surface, position)
  if not surface or not surface.get_tile then return false end
  local norm_pos = PositionUtils.normalize_position(position)
    if not norm_pos or norm_pos.x == nil or norm_pos.y == nil then return false end
    local tile = surface.get_tile(norm_pos.x, norm_pos.y)
  if not tile or not tile.valid then return false end
  -- Check tile name for water patterns - most reliable method
  local tile_name = tile.name
  local name = tile_name:lower()
  if name:find("water") or name:find("deepwater") or name:find("shallow%-water") or
      name == "water" or name == "deepwater" or name == "shallow-water" then
    return true
  end
  return false
end

--- Check if a tile at a position is space/void
--- Consolidated from multiple implementations across the codebase
---@param surface LuaSurface
---@param position MapPosition
---@return boolean is_space
function PositionUtils.is_space_tile(surface, position)
  if not surface or not surface.get_tile then return false end
  local norm_pos = PositionUtils.normalize_position(position)
    if not norm_pos or norm_pos.x == nil or norm_pos.y == nil then return false end
    local tile = surface.get_tile(norm_pos.x, norm_pos.y)
  if not tile or not tile.valid then return false end
  -- Check tile name for space patterns
  local tile_name = tile.name
  local name = tile_name:lower()
  if name:find("space") or name:find("void") or name == "out-of-map" or name == "space-platform" then
    return true
  end
  return false
end

--- Check if a position is walkable (same result as is_valid_tag_position, but does not require a player)
--- Consolidates logic from PositionUtils.is_walkable_position and other implementations
---@param surface LuaSurface
---@param position MapPosition
---@return boolean is_walkable
function PositionUtils.is_walkable_position(surface, position)
  if not surface or not position then
    ErrorHandler.debug_log("[WALKABLE] Invalid surface or position",
      { surface = surface and surface.name, position = position })
    return false
  end
  local norm_pos = PositionUtils.normalize_position(position)
    if not norm_pos or norm_pos.x == nil or norm_pos.y == nil then
      ErrorHandler.debug_log("[WALKABLE] Invalid normalized position", { position = position })
      return false
    end
    local tile = surface.get_tile(norm_pos.x, norm_pos.y)
    local tile_info = {
      surface = surface.name,
      surface_index = surface.index,
      orig_x = position.x,
      orig_y = position.y,
      norm_x = norm_pos.x,
      norm_y = norm_pos.y,
      tile_name = tile and tile.name or "<nil>",
      tile_prototype = tile and tile.prototype and tile.prototype.name or "<nil>",
      tile_valid = tile and tile.valid or false
    }
    Logger.debug_log("[WALKABLE] Tile info", tile_info)
    if not tile or not tile.valid then
      Logger.debug_log("[WALKABLE] Invalid tile", tile_info)
      return false
    end
    if PositionUtils.is_water_tile(surface, norm_pos) then
      Logger.debug_log("[WALKABLE] Position is water", tile_info)
      return false
    end
    if PositionUtils.is_space_tile(surface, norm_pos) then
      Logger.debug_log("[WALKABLE] Position is space/void", tile_info)
      return false
    end
    Logger.debug_log("[WALKABLE] Position is walkable", tile_info)
    return true
end

return PositionUtils
