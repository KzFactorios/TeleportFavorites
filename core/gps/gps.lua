--[[
core/gps/gps.lua
TeleportFavorites Factorio Mod
-----------------------------
GPS utility module for converting between canonical GPS strings, Factorio rich text tags, and map positions.

- Provides helpers for converting between map positions, GPS strings ('xxx.yyy.s'), and Factorio's [gps=x,y,s] rich text tags.
- Handles surface-aware GPS string formatting and parsing.
- Used throughout the mod for tag, favorite, and teleportation logic.


Notes:
------
- All GPS strings in this mod are canonical: 'xxx.yyy.s' (with padding and sign as needed).
- Use these helpers for all GPS conversions to ensure consistency and compatibility.
]]

local Constants = require("constants")
local basic_helpers = require("core.utils.basic_helpers")
local gps_helpers = require("core.utils.gps_helpers")

local GPS = {}

local padlen = Constants.settings.GPS_PAD_NUMBER

GPS.gps_from_map_position = gps_helpers.gps_from_map_position
GPS.map_position_from_gps = gps_helpers.map_position_from_gps
GPS.get_surface_index = gps_helpers.get_surface_index
GPS.normalize_landing_position = gps_helpers.normalize_landing_position

--- Returns the x,y as a string xxx.yyy, ignores the surface component
function GPS.coords_string_from_gps(gps)
  local parsed = gps_helpers.parse_gps_string(gps)
  return parsed and (basic_helpers.pad(parsed.x, padlen) .. "." .. basic_helpers.pad(parsed.y, padlen)) or nil
end

--- Converts our gps string (xxx.yyy.s) to Factorio's [gps=x,y,s] rich text tag
---@param gps string
---@return string|nil
function GPS.gps_to_gps_tag(gps)
  local parsed = gps_helpers.parse_gps_string(gps)
  return parsed and string.format("[gps=%d,%d,%d]", parsed.x, parsed.y, parsed.surface_index) or nil
end

--- Converts a Factorio [gps=x,y,s] rich text tag to our gps string (xxx.yyy.s)
---@param gps_tag string
---@return string|nil
function GPS.gps_from_gps_tag(gps_tag)
  if type(gps_tag) ~= "string" then return nil end
  local x, y, s = gps_tag:match("%[gps=(%-?%d+),(%-?%d+),(%-?%d+)%]")
  return (x and y and s) and (basic_helpers.pad(tonumber(x), padlen) .. "." .. basic_helpers.pad(tonumber(y), padlen) .. "." .. tostring(tonumber(s))) or nil
end

return GPS
