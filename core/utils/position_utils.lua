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
- terrain_validator.lua - Terrain validation and position finding

Provides a unified API for all position-related operations throughout the mod.
]]

local basic_helpers = require("core.utils.basic_helpers")
local Constants = require("constants")
local ErrorHandler = require("core.utils.error_handler")
local gps_helpers = require("core.utils.gps_helpers")
local GPSUtils = require("core.utils.gps_utils")
local LocaleUtils = require("core.utils.locale_utils")
local ValidationUtils = require("core.utils.validation_utils")

---@class PositionUtils
local PositionUtils = {}

--- Local player print function to avoid circular dependencies
--- @param player LuaPlayer Player to print message to
--- @param message string Message to print
local function safe_player_print(player, message)
  if player and player.valid and type(player.print) == "function" then
    ---@diagnostic disable-next-line: param-type-mismatch, missing-parameter, assign-type-mismatch
    player.print(message)
  end
end

-- ========================================
-- POSITION NORMALIZATION
-- ========================================

--- Normalize a map position to whole numbers
--- Consolidates position normalization logic from multiple files
---@param map_position MapPosition
---@return MapPosition normalized_position
function PositionUtils.normalize_position(map_position)
  local x = tonumber(basic_helpers.normalize_index(map_position.x or 0)) or 0
  local y = tonumber(basic_helpers.normalize_index(map_position.y or 0)) or 0
  return { x = x, y = y }
end

--- Check if a position needs normalization
---@param position MapPosition
---@return boolean
function PositionUtils.needs_normalization(position)
  return position and (not basic_helpers.is_whole_number(position.x) or 
                      not basic_helpers.is_whole_number(position.y))
end

--- Create old/new position pair for tracking position changes
---@param position MapPosition
---@return table {old: MapPosition, new: MapPosition}
function PositionUtils.create_position_pair(position)
  return {
    old = {x = position.x, y = position.y},
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

-- ========================================
-- TERRAIN VALIDATION
-- ========================================

--- Check if a tile at a position is water
--- Consolidated from multiple implementations across the codebase
---@param surface LuaSurface
---@param position MapPosition
---@return boolean is_water
function PositionUtils.is_water_tile(surface, position)
  if not surface or not surface.get_tile then return false end
  
  local x, y = math.floor(position.x), math.floor(position.y)
  local tile = surface:get_tile(x, y)
  if not tile or not tile.valid then return false end
  
  -- Check tile name for water patterns - most reliable method
  local tile_name = tile.name
  -- Check for various water tile naming patterns
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
  
  local tile = surface:get_tile(math.floor(position.x), math.floor(position.y))
  if not tile or not tile.valid then return false end
  
  -- Check tile name for space patterns
  local tile_name = tile.name
  local name = tile_name:lower()
  -- Common space tile names in Factorio
  if name:find("space") or name:find("void") or name == "out-of-map" then
    return true
  end
  
  return false
end

--- Check if a position is walkable (comprehensive validation)
--- Consolidates logic from PositionUtils.is_walkable_position and other implementations
---@param surface LuaSurface
---@param position MapPosition
---@param player LuaPlayer? Optional player context for space platform detection
---@return boolean is_walkable
function PositionUtils.is_walkable_position(surface, position, player)
  if not surface or not position then return false end
  
  -- Get the tile at the position
  local tile = surface:get_tile(position.x, position.y)
  if not tile or not tile.valid then return false end
  
  -- Primary check: Water tiles are never walkable
  if PositionUtils.is_water_tile(surface, position) then
    return false
  end
    -- Space tile validation with space platform context
  if PositionUtils.is_space_tile(surface, position) then
    -- If player is provided and is on a space platform, space tiles are walkable
    if player and PositionUtils.is_on_space_platform(player) then
      return true
    end
    
    -- For non-space platform surfaces, space tiles are not walkable
    return false
  end
  
  -- Use simpler walkability check based on tile properties
  -- If not water or space, consider it walkable
  return true
end

-- ========================================
-- POSITION SEARCH ALGORITHMS
-- ========================================

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
  if PositionUtils.is_walkable_position(surface, center_position, player) then
    return center_position
  end
  
  -- Search in expanding spiral pattern (more efficient than square pattern)
  local directions = {
    {x = 1, y = 0},  -- right    {x = 0, y = 1},  -- down
    {x = -1, y = 0}, -- left
    -- up
    {x = 0, y = -1}
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
        
        -- Get current direction safely        local current_dir = directions[dir_index]
        if not current_dir then
          -- Safety break if directions array is malformed
          break
        end
        
        -- Move in the current direction
        x = x + current_dir.x
        y = y + current_dir.y
        
        local check_pos = {x = x, y = y}
          -- Check if this position is walkable
        if PositionUtils.is_walkable_position(surface, check_pos, player) then
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
  if PositionUtils.is_walkable_position(surface, normalized_pos, player) then
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
  local pathfinding_pos = surface:find_non_colliding_position_in_box("character", bounding_box, 1.0)
    if pathfinding_pos and PositionUtils.is_walkable_position(surface, pathfinding_pos, player) then
    -- Normalize the pathfinding result and verify it's still valid
    local normalized_path_pos = PositionUtils.normalize_position(pathfinding_pos)
    
    if PositionUtils.is_walkable_position(surface, normalized_path_pos, player) then
      return normalized_path_pos
    end
  end
  
  return nil
end

--- Find a valid position using multiple search strategies
--- Combines both bounding box and spiral search methods for best results
---@param surface LuaSurface
---@param center_position MapPosition
---@param search_radius number? Optional search radius (default: 50)
---@param player LuaPlayer? Optional player context for space platform detection
---@return MapPosition? valid_position
function PositionUtils.find_valid_position(surface, center_position, search_radius, player)
  if not surface or not surface.valid or not center_position then return nil end
  
  -- Ensure coordinates are numbers
  if type(center_position.x) ~= "number" or type(center_position.y) ~= "number" then
    return nil
  end
  
  search_radius = search_radius or 50
    -- Strategy 1: Try bounding box method first (faster, more precise)
  local box_result = PositionUtils.find_valid_position_in_box(surface, center_position, nil, player)
  if box_result then
    return box_result
  end
    -- Strategy 2: Fall back to spiral search for wider coverage
  -- Limit spiral search to reasonable size
  local spiral_radius = math.min(search_radius, 20)
  local spiral_result = PositionUtils.find_nearest_walkable_position(surface, center_position, spiral_radius, player)
  if spiral_result then
    return spiral_result
  end
  
  -- No valid position found with any method
  return nil
end

-- ========================================
-- POSITION VALIDATION
-- ========================================

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
  end  -- Check if position is on water or space
  if PositionUtils.is_water_tile(player.surface, map_position) then
    if not skip_notification then
      safe_player_print(player, "[TeleportFavorites] Cannot tag water tiles")
    end
    return false
  end
    -- Space tile validation with space platform context
  if PositionUtils.is_space_tile(player.surface, map_position) then
    if PositionUtils.is_on_space_platform(player) then
      -- Space tiles are valid on space platforms
      return true
    else      -- Space tiles are invalid on regular surfaces
      if not skip_notification then
        safe_player_print(player, "[TeleportFavorites] Cannot tag space tiles")
      end
      return false
    end
  end
  
  return true
end

--- Returns true if a tag can be placed at the given map position for the player
---@param player LuaPlayer
---@param map_position table
---@return boolean
function PositionUtils.position_can_be_tagged(player, map_position)
  -- Use consolidated validation helper for player and position checks
  local valid, position, error_msg = ValidationUtils.validate_position_operation(player, 
    gps_helpers.gps_from_map_position(map_position, player and player.surface and player.surface.index or 1))
  if not valid then
    if error_msg then
      safe_player_print(player, "[TeleportFavorites] " .. error_msg)
    end
    return false
  end
  -- Check if the position is valid for tagging - handle nil position
  if not position then
    safe_player_print(player, LocaleUtils.get_error_string(player, "invalid_position"))
    return false
  end
  
  return PositionUtils.is_valid_tag_position(player, position, false)
end

--- Print a teleport event message to the player after successful teleportation
---@param player LuaPlayer
---@param gps string The GPS string of the destination
function PositionUtils.print_teleport_event_message(player, gps)
  if not player or not player.valid then return end
  
  local surface_index = GPSCore.get_surface_index_from_gps(gps) or 1
  local coords = GPSCore.coords_string_from_gps(gps)  -- Always show coords if available, otherwise fallback to GPS string
  if coords and coords ~= "" then
    safe_player_print(player, LocaleUtils.get_gui_string(player, "teleported_to_surface", {coords, tostring(surface_index)}))
  else
    safe_player_print(player, LocaleUtils.get_gui_string(player, "teleported_to_gps", {gps}))
  end
end

-- ========================================
-- TAG MOVEMENT OPERATIONS
-- ========================================

--- Move a tag to a selected position with validation and callback handling
--- This function is used by the tag editor move mode to relocate tags
---@param player LuaPlayer The player performing the move operation
---@param tag table The tag object to move
---@param chart_tag LuaCustomChartTag The chart tag associated with the tag
---@param new_position MapPosition The target position to move to
---@param search_radius number? Search radius for finding valid alternatives
---@param callback function? Callback function to handle validation results
---@return boolean success True if the move was successful, false otherwise
function PositionUtils.move_tag_to_selected_position(player, tag, chart_tag, new_position, search_radius, callback)
  -- Input validation
  if not player or not player.valid then
    ErrorHandler.warn_log("Move tag failed: Invalid player")
    return false
  end
  
  if not new_position or type(new_position.x) ~= "number" or type(new_position.y) ~= "number" then
    ErrorHandler.warn_log("Move tag failed: Invalid position")
    return false
  end
  
  -- Normalize the target position
  local normalized_position = PositionUtils.normalize_position(new_position)
  local surface_index = tonumber(player.surface.index) or 1
  
  -- First check if the position is valid for tagging
  if not PositionUtils.is_valid_tag_position(player, normalized_position, true) then
    -- Position is invalid (water, space, uncharted, etc.)
    if callback then
      -- Create tag data for the callback
      local tag_data = {
        gps = GPSUtils.gps_from_map_position(normalized_position, surface_index),
        tag = tag,
        chart_tag = chart_tag
      }
      
      -- Let the callback handle the invalid position (e.g., show dialog)
      callback("invalid_position", tag_data)
    end
    return false
  end
  
  -- Position is valid - proceed with the move
  local new_gps = GPSUtils.gps_from_map_position(normalized_position, surface_index)
  
  -- If we have a callback, use it for the successful move
  if callback then
    local tag_data = {
      gps = new_gps,
      tag = tag,
      chart_tag = chart_tag
    }
    callback("move", tag_data)
    return true
  end
  
  -- Fallback: direct move without callback (only if tag exists)
  local old_gps = tag and tag.gps or "unknown"
  tag.gps = new_gps
  
  ErrorHandler.debug_log("Tag moved to selected position", {
    player = player.name,
    old_gps = old_gps,
    new_gps = new_gps,
    position = normalized_position
  })
  
  return true
end

-- ========================================
-- SURFACE AND PLATFORM DETECTION
-- ========================================

--- Check if a player is currently on a space platform
--- Used for space tile validation - space tiles are walkable on space platforms
---@param player LuaPlayer Player to check
---@return boolean is_on_space_platform
function PositionUtils.is_on_space_platform(player)
  if not player or not player.surface or not player.surface.name then return false end
  local name = player.surface.name:lower()
  return name:find("space") ~= nil or name == "space-platform"
end

return PositionUtils
