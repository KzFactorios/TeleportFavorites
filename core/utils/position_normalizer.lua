---@diagnostic disable
--[[
core/utils/position_normalizer.lua
TeleportFavorites Factorio Mod
-----------------------------
Simple position normalization utilities.
]]

local basic_helpers = require("core.utils.basic_helpers")

---@class PositionNormalizer
local PositionNormalizer = {}

--- Check if a position needs normalization
---@param position MapPosition
---@return boolean
function PositionNormalizer.needs_normalization(position)
  return position and (not basic_helpers.is_whole_number(position.x) or 
                      not basic_helpers.is_whole_number(position.y))
end

--- Create old/new position pair
---@param position MapPosition
---@return table {old: MapPosition, new: MapPosition}
function PositionNormalizer.create_position_pair(position)
  return {
    old = {x = position.x, y = position.y},
    new = {
      x = basic_helpers.normalize_index(position.x),
      y = basic_helpers.normalize_index(position.y)
    }
  }
end

return PositionNormalizer
