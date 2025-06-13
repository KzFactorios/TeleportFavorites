---@diagnostic disable: undefined-global
--[[
core/utils/position_validator.lua
TeleportFavorites Factorio Mod
-----------------------------
Position validation and correction utilities for map locations.

This module handles:
- Validation of positions for teleportation (water, space, etc.)
- Finding alternative valid positions when needed
- Position correction notifications
- Managing tag/chart_tag relocation
]]

local Helpers = require("core.utils.helpers_suite")
local ErrorHandler = require("core.utils.error_handler")
local GPSCore = require("core.utils.gps_core")
local Cache = require("core.cache.cache")
local basic_helpers = require("core.utils.basic_helpers")

---@class PositionValidator
local PositionValidator = {}

--- Check if a position is valid for tagging (no water/space)
---@param player LuaPlayer
---@param map_position MapPosition
---@param skip_notification boolean? Whether to skip player notification on failure
---@return boolean is_valid
function PositionValidator.is_valid_tag_position(player, map_position, skip_notification)
  if not player or not player.valid or not map_position then
    return false
  end
  
  -- Validate x and y are numbers
  if type(map_position.x) ~= "number" or type(map_position.y) ~= "number" then
    return false
  end    -- Check if position is on water tile
  if Helpers.is_water_tile(player.surface, map_position) then
    if not skip_notification then
      -- Debug output for water detection
      game.print("[DEBUG] Water tile detected at " .. map_position.x .. ", " .. map_position.y)
      local location_gps = GPSCore.gps_from_map_position(map_position, player.surface.index)
      game.print("[TeleportFavorites] Cannot tag water location: " .. location_gps)
    end
    return false
  end
    -- Check if position is on space tile
  if Helpers.is_space_tile(player.surface, map_position) then
    if not skip_notification then
      local location_gps = GPSCore.gps_from_map_position(map_position, player.surface.index)
      game.print("[TeleportFavorites] Cannot tag space location: " .. location_gps)
    end
    return false
  end
  
  return true
end

--- Find a valid position nearby for tag placement
---@param player LuaPlayer
---@param normalized_pos MapPosition
---@param search_radius number? Optional search radius (default 50)
---@return MapPosition? valid_position
function PositionValidator.find_valid_position(player, normalized_pos, search_radius)
  if not player or not player.valid or not normalized_pos then
    return nil
  end
  
  -- Ensure coordinates are numbers
  if type(normalized_pos.x) ~= "number" or type(normalized_pos.y) ~= "number" then
    return nil
  end
  
  -- First check if the original position is already valid
  if PositionValidator.is_valid_tag_position(player, normalized_pos, true) then
    return normalized_pos
  end
  
  -- Search in expanding squares around the position for a valid tag position
  local max_radius = math.min(search_radius or 50, 50) -- Cap the search radius
  
  for radius = 1, max_radius do
    -- Check the perimeter of the current radius
    for dx = -radius, radius do
      for dy = -radius, radius do
        -- Only check positions on the perimeter of the square
        if math.abs(dx) == radius or math.abs(dy) == radius then
          local test_pos = {
            x = normalized_pos.x + dx,
            y = normalized_pos.y + dy
          }
          
          -- Check if this position is valid for tagging
          if PositionValidator.is_valid_tag_position(player, test_pos, true) then
            return test_pos
          end
        end
      end
    end
  end
  
  return nil -- No valid position found within search radius
end

--- Attempt to move a tag to a valid position
---@param player LuaPlayer
---@param tag_data table Tag data with gps field
---@return boolean success Whether the tag was successfully moved
function PositionValidator.move_tag_to_valid_position(player, tag_data)
  if not player or not player.valid or not tag_data or not tag_data.gps then
    return false
  end
  
  local position = GPSCore.map_position_from_gps(tag_data.gps)
  if not position then
    return false
  end
  
  local valid_position = PositionValidator.find_valid_position(player, position, 50)  if valid_position then
    -- Update the tag's GPS to the new valid position
    tag_data.gps = GPSCore.gps_from_map_position(valid_position, player.surface.index)
    game.print("[TeleportFavorites] Tag moved to valid position: " .. tag_data.gps)
    return true
  else
    game.print("[TeleportFavorites] No valid position found nearby. Tag movement failed.")
    return false
  end
end

return PositionValidator
