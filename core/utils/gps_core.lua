---@diagnostic disable
--[[
core/utils/gps_core.lua
TeleportFavorites Factorio Mod
-----------------------------
Core GPS parsing, validation, and conversion utilities.

- Canonical GPS strings: 'xxx.yyy.s' (x/y padded, s = surface index)
- Basic conversion between GPS strings and MapPosition tables
- Validation patterns for tags and chart tags
- No complex dependencies - only basic helpers and constants
]]

local basic_helpers = require("core.utils.basic_helpers")
local Constants = require("constants")

local padlen, BLANK_GPS = Constants.settings.GPS_PAD_NUMBER, Constants.settings.BLANK_GPS

---@class GPSCore
local GPSCore = {}

-- Common validation patterns for standardization
local ValidationPatterns = {}

--- Standardized way to check if a tag is valid and usable
---@param tag table?
---@return boolean
function ValidationPatterns.is_valid_tag(tag)
  if not tag then return false end
  return tag.gps and type(tag.gps) == "string" and true or false
end

--- Standardized way to check if a chart tag is valid
---@param chart_tag LuaCustomChartTag?
---@return boolean
function ValidationPatterns.is_valid_chart_tag(chart_tag) 
  if not chart_tag then return false end
  return chart_tag.valid
end

--- Parse a GPS string 'x.y.s' into {x, y, surface_index} or nil if invalid
---@param gps string
---@return table|nil
local function parse_gps_string(gps)
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

--- Return canonical GPS string 'xxx.yyy.s' from map position and surface index
---@param map_position MapPosition
---@param surface_index uint
---@return string
local function gps_from_map_position(map_position, surface_index)
  return basic_helpers.pad(map_position.x, padlen) ..
      "." .. basic_helpers.pad(map_position.y, padlen) ..
      "." .. tostring(surface_index)
end

--- Convert GPS string to MapPosition {x, y} (surface not included)  
---@param gps string
---@return MapPosition?
local function map_position_from_gps(gps)
  if gps == BLANK_GPS then return nil end
  local parsed = parse_gps_string(gps)
  return parsed and { x = parsed.x, y = parsed.y } or nil
end

--- Get surface index from GPS string (returns nil if invalid)
---@param gps string
---@return uint?
local function get_surface_index_from_gps(gps)
  if gps == BLANK_GPS then return nil end
  local parsed = parse_gps_string(gps)
  return parsed and parsed.s or nil
end

--- Parse and normalize a GPS string; accepts vanilla [gps=x,y,s] or canonical format
---@param gps string
---@return string
local function parse_and_normalize_gps(gps)
  if type(gps) == "string" and gps:match("^%[gps=") then
    local x, y, s = gps:match("%[gps=(%-?%d+),(%-?%d+),(%-?%d+)%]")
    if x and y and s then
      local nx, ny, ns = basic_helpers.normalize_index(x), basic_helpers.normalize_index(y), tonumber(s)
      if nx and ny and ns then
        return gps_from_map_position({ x = nx, y = ny }, math.floor(ns))
      end
    end
    return BLANK_GPS
  end
  return gps or BLANK_GPS
end

-- Export public functions
GPSCore.BLANK_GPS = BLANK_GPS
GPSCore.parse_gps_string = parse_gps_string
GPSCore.gps_from_map_position = gps_from_map_position
GPSCore.map_position_from_gps = map_position_from_gps
GPSCore.get_surface_index_from_gps = get_surface_index_from_gps
GPSCore.parse_and_normalize_gps = parse_and_normalize_gps
GPSCore.ValidationPatterns = ValidationPatterns

return GPSCore
