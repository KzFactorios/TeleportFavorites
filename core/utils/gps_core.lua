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

This module provides the single source of truth for GPS parsing functions.
All other modules should use this instead of duplicating GPS logic.
]]

local GPSParser = require("core.utils.gps_parser")
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

--- Parse and normalize a GPS string; accepts vanilla [gps=x,y,s] or canonical format
--- Converts Factorio's vanilla GPS format to mod's canonical format
---
--- @param gps string GPS string in vanilla "[gps=x,y,s]" or canonical "xxx.yyy.s" format
--- @return string Normalized GPS string in canonical format "xxx.yyy.s" or BLANK_GPS if invalid
---
--- @example
--- parse_and_normalize_gps("[gps=123,456,1]") -> "123.456.1"
--- parse_and_normalize_gps("123.456.1")      -> "123.456.1"
--- parse_and_normalize_gps("")               -> "1000000.1000000.1" (BLANK_GPS)
--- parse_and_normalize_gps(nil)              -> "1000000.1000000.1" (BLANK_GPS)
local function parse_and_normalize_gps(gps)
  if type(gps) == "string" and gps:match("^%[gps=") then
    local x, y, s = gps:match("%[gps=(%-?%d+),(%-?%d+),(%-?%d+)%]")
    if x and y and s then
      local nx, ny, ns = basic_helpers.normalize_index(x), basic_helpers.normalize_index(y), tonumber(s)
      if nx and ny and ns then
        return GPSParser.gps_from_map_position({ x = nx, y = ny }, math.floor(ns))
      end
    end
    return BLANK_GPS
  end
  return gps or BLANK_GPS
end

--- Converts a GPS string to coordinate string format "xxx.yyy"
--- Excludes surface component, only returns x.y coordinates with padding
--- Centralized implementation to avoid duplication across modules
---
--- @param gps string GPS string in format "xxx.yyy.s" or ""
--- @return string Formatted coordinate string "xxx.yyy" (padded to 3 digits) or "" if invalid
---
--- @example
--- coords_string_from_gps("123.456.1")     -> "123.456"
--- coords_string_from_gps("-005.010.2")    -> "-005.010"
--- coords_string_from_gps("1000000.1000000.1") -> ""  (BLANK_GPS)
--- coords_string_from_gps("")              -> ""
local function coords_string_from_gps(gps)
  if not gps or type(gps) ~= "string" or basic_helpers.trim(gps) == "" or gps == BLANK_GPS then 
    return "" 
  end
  
  local parsed = GPSParser.parse_gps_string(gps)
  if not parsed or type(parsed.x) ~= "number" or type(parsed.y) ~= "number" then 
    return "" 
  end
  
  return basic_helpers.pad(parsed.x, padlen) .. "." .. basic_helpers.pad(parsed.y, padlen)
end

--- Converts a MapPosition to coordinate string format "xxx.yyy"
--- Excludes surface component, only returns x.y coordinates with padding
--- Centralized implementation to avoid duplication across modules
---
--- @param map_position MapPosition Table with x,y numeric coordinates {x=number, y=number}
--- @return string Formatted coordinate string "xxx.yyy" (padded to 3 digits) or "" if invalid
---
--- @example
--- coords_string_from_map_position({x=123, y=456}) -> "123.456"
--- coords_string_from_map_position({x=-5, y=10})  -> "-005.010"
--- coords_string_from_map_position({x=0, y=0})    -> "000.000"
--- coords_string_from_map_position(nil)           -> ""
local function coords_string_from_map_position(map_position)
  -- Validate input parameter type
  if type(map_position) ~= "table" then 
    return "" 
  end
  
  local x, y = map_position.x, map_position.y
  
  -- Validate coordinates are numbers
  if type(x) ~= "number" or type(y) ~= "number" then 
    return "" 
  end
  
  return basic_helpers.pad(x, padlen) .. "." .. basic_helpers.pad(y, padlen)
end

-- Export public functions - delegate to GPSParser for core functions
GPSCore.BLANK_GPS = BLANK_GPS
GPSCore.parse_gps_string = GPSParser.parse_gps_string
GPSCore.gps_from_map_position = GPSParser.gps_from_map_position
GPSCore.map_position_from_gps = GPSParser.map_position_from_gps
GPSCore.get_surface_index_from_gps = GPSParser.get_surface_index_from_gps
GPSCore.parse_and_normalize_gps = parse_and_normalize_gps
GPSCore.coords_string_from_gps = coords_string_from_gps
GPSCore.coords_string_from_map_position = coords_string_from_map_position
GPSCore.ValidationPatterns = ValidationPatterns

return GPSCore
