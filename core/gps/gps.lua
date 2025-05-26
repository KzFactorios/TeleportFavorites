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
function GPS.gps_string_from_gps(gps)
  local parsed = gps_helpers.parse_gps_string(gps)
  if not parsed then return nil end
  return Helpers.pad(parsed.x, Constants.settings.GPS_PAD_NUMBER) .. "." .. Helpers.pad(parsed.y, Constants.settings.GPS_PAD_NUMBER) .. "." .. tostring(parsed.s or parsed.surface or parsed.surface_index)
end

return GPS
