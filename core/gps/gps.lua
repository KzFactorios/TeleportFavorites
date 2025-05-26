local Constants = require("constants")
local Settings = require("settings")
local Helpers = require("core.utils.helpers")
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
  if not parsed then return nil end
  return Helpers.pad(parsed.x, Constants.settings.GPS_PAD_NUMBER) .. "." .. Helpers.pad(parsed.y, Constants.settings.GPS_PAD_NUMBER)
end

--- Returns the full GPS string in canonical format xxx.yyy.s
--[[function GPS.gps_string_from_gps(gps)
  local parsed = gps_helpers.parse_gps_string(gps)
  if not parsed then return nil end
  return Helpers.pad(parsed.x, Constants.settings.GPS_PAD_NUMBER) .. "." .. Helpers.pad(parsed.y, Constants.settings.GPS_PAD_NUMBER) .. "." .. tostring(parsed.s or parsed.surface or parsed.surface_index)
end]]

--- Converts our gps string (xxx.yyy.s) to Factorio's [gps=x,y,s] rich text tag
---@param gps string
---@return string|nil
function GPS.gps_to_gps_tag(gps)
  local parsed = gps_helpers.parse_gps_string(gps)
  if not parsed then return nil end
  return string.format("[gps=%d,%d,%d]", parsed.x, parsed.y, parsed.surface_index)
end

--- Converts a Factorio [gps=x,y,s] rich text tag to our gps string (xxx.yyy.s)
---@param gps_tag string
---@return string|nil
function GPS.gps_from_gps_tag(gps_tag)
  if type(gps_tag) ~= "string" then return nil end
  local x, y, s = gps_tag:match("%[gps=(%-?%d+),(%-?%d+),(%-?%d+)%]")
  if not x or not y or not s then return nil end
  -- Use the same padding as our canonical format
  return Helpers.pad(tonumber(x), padlen) .. "." .. Helpers.pad(tonumber(y), padlen) .. "." .. tostring(tonumber(s))
end

return GPS
