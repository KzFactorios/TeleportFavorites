---@diagnostic disable: undefined-global, param-type-mismatch
--[[
core/utils/position_utils.lua
TeleportFavorites Factorio Mod
-----------------------------
Consolidated position utilities combining all position-related functionality.

This module consolidates:
- position_helpers.lua - Position validation and tagging checks
- position_normalizer.lua - Position normalization utilities
- position_validator.lua - Position validation and correction

Provides a unified API for all position-related operations throughout the mod.
]]

local basic_helpers = require("core.utils.basic_helpers")
local Constants = require("constants")
local ErrorHandler = require("core.utils.error_handler")
local GPSUtils = require("core.utils.gps_utils")
local LocaleUtils = require("core.utils.locale_utils")
local ValidationUtils = require("core.utils.validation_utils")
local Logger = require("core.utils.enhanced_error_handler")

---@class PositionUtils
local PositionUtils = {}

--- Normalize a map position to whole numbers
--- Consolidates position normalization logic from multiple files
---@param map_position MapPosition
---@return MapPosition normalized_position
function PositionUtils.normalize_position(map_position)
  if not map_position then
    return {x = 0, y = 0}
  end
  
  -- Handle both array-style [x, y] and object-style {x = ..., y = ...} positions
  local x, y
  if map_position.x ~= nil and map_position.y ~= nil then
    x, y = map_position.x, map_position.y
  elseif type(map_position) == "table" and #map_position >= 2 then
    x, y = map_position[1], map_position[2]
  else
    return {x = 0, y = 0}
  end
  
  return {x = math.floor(x), y = math.floor(y)}
end

--- Check if a position needs normalization
---@param position MapPosition
---@return boolean
function PositionUtils.needs_normalization(position)
  return position and (not basic_helpers.is_whole_number(position.x) or
    not basic_helpers.is_whole_number(position.y))
end

--- Check if a position is valid
---@param position MapPosition
---@return boolean
function PositionUtils.is_valid_position(position)
  return position and position.x and position.y and true or false
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

--- Normalize a position only if it needs normalization
---@param position MapPosition
---@return MapPosition normalized_position
function PositionUtils.normalize_if_needed(position)
  if PositionUtils.needs_normalization(position) then
    return PositionUtils.normalize_position(position)
  end
  return position
end

--- Check if a tile at a position is water
--- Consolidated from multiple implementations across the codebase
---@param surface LuaSurface
---@param position MapPosition
---@return boolean is_water
function PositionUtils.is_water_tile(surface, position)
  if not surface or not surface.get_tile then return false end
  local norm_pos = PositionUtils.needs_normalization(position) and PositionUtils.normalize_position(position) or position
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
  local norm_pos = PositionUtils.needs_normalization(position) and PositionUtils.normalize_position(position) or position
  local tile = surface.get_tile(norm_pos.x, norm_pos.y)
  if not tile or not tile.valid then return false end
  -- Check tile name for space patterns
  local tile_name = tile.name
  local name = tile_name:lower()
  if name:find("space") or name:find("void") or name == "out-of-map" then
    return true
  end
  return false
end

--- Check if a position appears walkable (not water/space) - simplified version
---@param surface LuaSurface
---@param position MapPosition
---@return boolean appears_walkable
function PositionUtils.appears_walkable(surface, position)
  if not surface or not position then return false end
  
  -- Use existing water and space tile checking
  if PositionUtils.is_water_tile(surface, position) then
    return false
  end
  
  if PositionUtils.is_space_tile(surface, position) then
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
function PositionUtils.find_safe_landing_position(surface, position, search_radius, precision)
  if not surface or not position then return nil end
  
  search_radius = search_radius or 16.0
  precision = precision or 0.5
  
  -- Use Factorio's built-in collision detection to find a safe position
  return surface.find_non_colliding_position("character", position, search_radius, precision)
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
  -- Normalize position to whole numbers before tile checks
  local norm_pos = PositionUtils.normalize_position(position)
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
  if PositionUtils.is_on_space_platform(surface) then
    Logger.debug_log("[WALKABLE] Surface is space platform", tile_info)
    return false
  end
  Logger.debug_log("[WALKABLE] Position is walkable", tile_info)
  return true
end

--- Find a valid (walkable) position near a target position using spiral search
--- Consolidates search logic from multiple files
---@param surface LuaSurface
---@param center_position MapPosition
---@param max_radius number Maximum search radius (default: 20)
---@param player LuaPlayer? Optional player context for space platform detection
---@return MapPosition? valid_position
function PositionUtils.find_nearest_walkable_position(surface, center_position, max_radius, player)
  if not surface or not surface.valid or not center_position then return nil end

  max_radius = max_radius or 20
  -- Check the original position first - might already be valid
  if PositionUtils.is_walkable_position(surface, center_position) then
    return center_position
  end

  -- Search in expanding spiral pattern (more efficient than square pattern)
  local directions = {
    { x = 1,  y = 0 }, -- right    {x = 0, y = 1},  -- down
    { x = -1, y = 0 }, -- left
    -- up
    { x = 0,  y = -1 }
  }

  local x, y = center_position.x, center_position.y
  local dir_index = 1
  local steps = 1
  for radius = 1, max_radius do
    -- Two segments per radius level
    for _ = 1, 2 do
      for _ = 1, steps do
        -- Ensure dir_index is within bounds
        if dir_index > #directions then
          dir_index = 1
        end

        -- Get current direction safely
        local current_dir = directions[dir_index]
        if not current_dir then
          -- Safety break if directions array is malformed
          break
        end

        -- Move in the current direction
        x = x + current_dir.x
        y = y + current_dir.y

        local check_pos = { x = x, y = y }
        -- Check if this position is walkable
        if PositionUtils.is_walkable_position(surface, check_pos) then
          return check_pos
        end
      end

      -- Change direction
      dir_index = (dir_index % 4) + 1
    end

    -- Increase step count for next radius
    steps = steps + 1
  end

  -- No valid position found within search radius
  return nil
end

--- Find valid position using bounding box method (alternative to spiral search)
--- Consolidates logic from PositionValidator.find_valid_position
---@param surface LuaSurface
---@param center_position MapPosition
---@param tolerance number? Bounding box tolerance (default: 4)
---@param player LuaPlayer? Optional player context for space platform detection
---@return MapPosition? valid_position
function PositionUtils.find_valid_position_in_box(surface, center_position, tolerance, player)
  if not surface or not surface.valid or not center_position then return nil end

  local box_tolerance = tolerance or 4
  if Constants.settings.BOUNDING_BOX_TOLERANCE then
    box_tolerance = tonumber(Constants.settings.BOUNDING_BOX_TOLERANCE) or 4
  end

  -- Normalize the center position first
  local normalized_pos = PositionUtils.normalize_position(center_position)
  -- Check if normalized position is already valid
  if PositionUtils.is_walkable_position(surface, normalized_pos) then
    return normalized_pos
  end

  -- Create bounding box for pathfinding search
  local bounding_box = {
    left_top = {
      x = normalized_pos.x - box_tolerance,
      y = normalized_pos.y - box_tolerance
    },
    right_bottom = {
      x = normalized_pos.x + box_tolerance,
      y = normalized_pos.y + box_tolerance
    }
  }

  -- Try Factorio's pathfinding using bounding box method
  local pathfinding_pos = surface.find_non_colliding_position_in_box("character", bounding_box, 1.0, false)
  if pathfinding_pos and PositionUtils.is_walkable_position(surface, pathfinding_pos) then
    -- Normalize the pathfinding result and verify it's still valid
    local normalized_path_pos = PositionUtils.normalize_position(pathfinding_pos)

    if PositionUtils.is_walkable_position(surface, normalized_path_pos) then
      return normalized_path_pos
    end
  end

  return nil
end

--- Check if a position is valid for tagging (no water/space)
---@param player LuaPlayer
---@param map_position MapPosition
---@param skip_notification boolean? Whether to skip player notification on failure
---@return boolean is_valid
function PositionUtils.is_valid_tag_position(player, map_position, skip_notification)
  -- Use consolidated validation helper for player check
  local player_valid, player_error = ValidationUtils.validate_player(player)
  if not player_valid then
    if not skip_notification then
      ErrorHandler.warn_log("Position validation failed: " .. (player_error or "Invalid player"))
    end
    return false
  end -- Water tiles are now allowed for tagging (removed restriction)
  -- if PositionUtils.is_water_tile(player.surface, map_position) then
  --   if not skip_notification then
  --     safe_player_print(player, "[TeleportFavorites] Cannot tag water tiles")
  --   end
  --   return false
  -- end
  -- Space tile validation with space platform context
  if PositionUtils.is_space_tile(player.surface, map_position) then
    if PositionUtils.is_on_space_platform(player.surface) then
      -- Space tiles are valid on space platforms
      return true
    else -- Space tiles are invalid on regular surfaces
      if not skip_notification then
        safe_player_print(player, "[TeleportFavorites] Cannot tag space tiles")
      end
      return false
    end
  end

  return true
end

--- Check if a player is currently on a space platform
--- Used for space tile validation - space tiles are walkable on space platforms
---@param surface LuaSurface Player to check
---@return boolean is_on_space_platform
function PositionUtils.is_on_space_platform(surface)
  if not surface then return false end
  local name = surface.name:lower()
  return name:find("space") ~= nil or name == "space-platform"
end

return PositionUtils
