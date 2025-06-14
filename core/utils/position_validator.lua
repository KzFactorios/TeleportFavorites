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
local GPSCore = require("core.utils.gps_core")
local game_helpers = require("core.utils.game_helpers")
local basic_helpers = require("core.utils.basic_helpers")
local Constants = require("constants")

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
  end

  -- Check if position is walkable (this replaces separate water/space checks)
  if not Helpers.is_walkable_position(player.surface, map_position) then
    if not skip_notification then
      -- Debug output for non-walkable position detection
      local location_gps = GPSCore.gps_from_map_position(map_position, player.surface.index)
      game_helpers.player_print("[TeleportFavorites] Cannot tag non-walkable location: " .. location_gps)
    end
    return false
  end

  return true
end

---@param map_position MapPosition
---@return MapPosition
function PositionValidator.normalize_map_position(map_position)
  local x = tonumber(basic_helpers.normalize_index(map_position.x or 0)) or 0
  local y = tonumber(basic_helpers.normalize_index(map_position.y or 0)) or 0
  return { x = x, y = y }
end

--- Find a valid position nearby for tag placement
---@param player LuaPlayer
---@param map_position MapPosition
---@param search_radius number? Optional search radius (default 50)
---@return MapPosition? valid_position
function PositionValidator.find_valid_position(player, map_position, search_radius)
  if not player or not player.valid or not map_position then
    return nil
  end

  -- Ensure coordinates are numbers
  if type(map_position.x) ~= "number" or type(map_position.y) ~= "number" then
    return nil
  end

  local normalized_pos = PositionValidator.normalize_map_position(map_position)

  -- First check if the original position is already valid
  if PositionValidator.is_valid_tag_position(player, normalized_pos, true) then
    return normalized_pos
  end

  -- Create a bounding box around the normalized_pos
  local tolerance = Constants.settings.BOUNDING_BOX_TOLERANCE or 4
  local bounding_box = {
    left_top = {
      x = normalized_pos.x - tolerance,
      y = normalized_pos.y - tolerance
    },
    right_bottom = {
      x = normalized_pos.x + tolerance,
      y = normalized_pos.y + tolerance
    }
  }

  -- Try Factorio's pathfinding first
  local pathfinding_pos = player.surface.find_non_colliding_position_in_box("character", bounding_box, 1)
  
  if pathfinding_pos and PositionValidator.is_valid_tag_position(player, pathfinding_pos, true) then
  -- find the closest, normalize it's coords and check validity
    local normalized_path_pos = PositionValidator.normalize_map_position(pathfinding_pos)
    if normalized_path_pos and PositionValidator.is_valid_tag_position(player, normalized_path_pos, true) then
      return normalized_path_pos
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

  local valid_position = PositionValidator.find_valid_position(player, position, 50)
  if valid_position then
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
