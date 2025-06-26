--[[
position_tile_helpers.lua
TeleportFavorites Factorio Mod
-----------------------------
Shared, dependency-free helpers for position normalization and tile checks.
This module is used by both tile_utils.lua and position_utils.lua to avoid circular dependencies.
]]

local basic_helpers = require("core.utils.basic_helpers")

local PositionTileHelpers = {}

--- Normalize a map position to whole numbers
---@param map_position MapPosition
---@return MapPosition normalized_position
function PositionTileHelpers.normalize_position(map_position)
  local x = tonumber(basic_helpers.normalize_index(map_position.x or 0)) or 0
  local y = tonumber(basic_helpers.normalize_index(map_position.y or 0)) or 0
  return { x = x, y = y }
end

--- Check if a position needs normalization
---@param position MapPosition
---@return boolean
function PositionTileHelpers.needs_normalization(position)
  return position and (not basic_helpers.is_whole_number(position.x) or
    not basic_helpers.is_whole_number(position.y))
end

return PositionTileHelpers
