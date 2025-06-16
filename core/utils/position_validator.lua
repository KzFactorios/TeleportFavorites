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

local GPSCore = require("core.utils.gps_utils")
local game_helpers = require("core.utils.game_helpers")
local PositionUtils = require("core.utils.position_utils")
local ValidationHelpers = require("core.utils.validation_helpers")
local TerrainValidator = require("core.utils.terrain_validator")
local LocaleUtils = require("core.utils.locale_utils")

---@class PositionValidator
local PositionValidator = {}

--- Check if a position is valid for tagging (no water/space)
---@param player LuaPlayer
---@param map_position MapPosition
---@param skip_notification boolean? Whether to skip player notification on failure
---@return boolean is_valid
function PositionValidator.is_valid_tag_position(player, map_position, skip_notification)
  -- Use consolidated validation helper for player check
  local player_valid, player_error = ValidationHelpers.validate_player(player)
  if not player_valid then
    return false
  end
  
  -- Use consolidated validation helper for position structure check
  local pos_valid, pos_error = ValidationHelpers.validate_position_structure(map_position)
  if not pos_valid then
    return false
  end  -- Check if position is walkable (consolidated terrain validation with space platform support)
  if not PositionUtils.is_walkable_position(player.surface, map_position, player) then
    if not skip_notification then
      -- Debug output for non-walkable position detection
      local surface_index = tonumber(player.surface.index) or 1
      local location_gps = GPSCore.gps_from_map_position(map_position, surface_index)
      game_helpers.player_print(player, LocaleUtils.get_error_string(player, "cannot_tag_nonwalkable", {location_gps}))
    end
    return false
  end

  return true
end

---@param map_position MapPosition
---@return MapPosition
function PositionValidator.normalize_map_position(map_position)
  return TerrainValidator.normalize_position(map_position)
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
  -- Use consolidated position utils for comprehensive position finding with space platform support
  return PositionUtils.find_valid_position(player.surface, map_position, search_radius, player)
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
    local surface_index = tonumber(player.surface.index) or 1
    tag_data.gps = GPSCore.gps_from_map_position(valid_position, surface_index)
    game.print("[TeleportFavorites] Tag moved to valid position: " .. tag_data.gps)
    return true
  else
    game.print("[TeleportFavorites] No valid position found nearby. Tag movement failed.")
    return false
  end
end

return PositionValidator
