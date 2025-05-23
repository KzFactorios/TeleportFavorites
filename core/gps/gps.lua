local Constants = require("constants")
local Helpers = require("core.utils.Helpers")
local Cache = require("core/cache/cache")

local GPS = {}

local padlen = Constants.settings.GPS_PAD_NUMBER

--- Parse a GPS string of the form 'x.y.s' into a table {x=..., y=..., surface=...}
---@param gps string
---@return table|nil
local function parse_gps_string(gps)
  local x, y, s = string.match(gps, "^([%d%.-]+)%.([%d%.-]+)%.([%d%.-]+)$")
  if not x or not y or not s then return nil end
  return { x = tonumber(x), y = tonumber(y), surface = tonumber(s) }
end

--- Return the GPS string in the format xxx.yyy.s
---@param map_position MapPosition
---@param surface_index number
---@return string
function GPS.gps_from_map_position(map_position, surface_index)
  return Helpers.pad(map_position.x, padlen) .. "." .. Helpers.pad(map_position.y, padlen) .. "." .. tostring(surface_index)
end

--- Convert a gps string to a MapPosition {x,y}. Surface index is not included
---@param gps string
---@return MapPosition|nil
function GPS.map_position_from_gps(gps)
  local parsed = parse_gps_string(gps)
  if not parsed then return nil end
  return { x = parsed.x, y = parsed.y }
end

--- Given a gps string, return the xxx.yyy portion as a string (no surface index)
---@param gps string
---@return string|nil
function GPS.coords_string_from_gps(gps)
  local parsed = parse_gps_string(gps)
  if not parsed then return nil end
      return Helpers.pad(parsed.x, padlen) .. "." .. Helpers.pad(parsed.y, padlen)
end

--- Find a Tag object by GPS string
---@param gps string
---@return Tag|nil
function GPS.find_tag_by_gps(gps)
  local surface_index = GPS.get_surface_index(gps)
  if not surface_index then return nil end
  local surface_data = Cache.get_surface_data(surface_index)
  if not surface_data or not surface_data.tags then return nil end
  return surface_data.tags[gps]
end

--- Get the surface index from a gps string
---@param gps string
---@return number|nil
function GPS.get_surface_index(gps)
  local parsed = parse_gps_string(gps)
  if not parsed then return nil end
  return parsed.surface
end

return GPS