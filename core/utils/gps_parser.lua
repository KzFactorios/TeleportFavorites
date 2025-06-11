--[[
core/utils/gps_parser.lua
TeleportFavorites Factorio Mod
-----------------------------
Minimal GPS parsing utilities with no external dependencies (except basic_helpers and constants).
This module breaks circular dependencies by providing core GPS parsing without requiring Cache or other complex modules.

USAGE:
- Use this module for basic GPS string parsing and validation
- For complex GPS operations requiring Cache access, use gps_helpers.lua
- For GPS conversion and formatting, use core/gps/gps.lua
]]

local basic_helpers = require("core.utils.basic_helpers")
local Constants = require("constants")

local padlen, BLANK_GPS = Constants.settings.GPS_PAD_NUMBER, Constants.settings.BLANK_GPS

---@class GPSParser
local GPSParser = {}

--- Parse a GPS string 'x.y.s' into {x, y, surface_index} or nil if invalid
---@param gps string
---@return table|nil
function GPSParser.parse_gps_string(gps)
  if type(gps) ~= "string" then return nil end
  if gps == BLANK_GPS then return { x = 0, y = 0, s = -1 } end

  local x, y, s = gps:match("^(%-?%d+)%.(%-?%d+)%.(%d+)$")
  if not x or not y or not s then return nil end
  local parsed_x, parsed_y, parsed_s = tonumber(x), tonumber(y), tonumber(s)
  if not parsed_x or not parsed_y or not parsed_s then return nil end
  local ret = {
    x = basic_helpers.normalize_index(parsed_x),
    y = basic_helpers.normalize_index(parsed_y),
    s = basic_helpers.normalize_index(parsed_s)
  }
  return ret
end

--- Get surface index from GPS string (returns nil if invalid)
---@param gps string
---@return uint?
function GPSParser.get_surface_index_from_gps(gps)
  if gps == BLANK_GPS then return nil end
  local parsed = GPSParser.parse_gps_string(gps)
  return parsed and parsed.s or nil
end

--- Return canonical GPS string 'xxx.yyy.s' from map position and surface index
---@param map_position MapPosition
---@param surface_index number
---@return string
function GPSParser.gps_from_map_position(map_position, surface_index)
  if not map_position or not surface_index or surface_index <= 0 then return BLANK_GPS end
  return basic_helpers.pad(map_position.x, padlen) ..
      "." .. basic_helpers.pad(map_position.y, padlen) ..
      "." .. tostring(math.floor(surface_index))
end

--- Convert GPS string to MapPosition {x, y} (surface not included)
---@param gps string
---@return MapPosition?
function GPSParser.map_position_from_gps(gps)
  if gps == BLANK_GPS then return nil end
  local parsed = GPSParser.parse_gps_string(gps)
  return parsed and { x = parsed.x, y = parsed.y } or nil
end

return GPSParser
