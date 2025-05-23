local Constants = require("constants")
local Cache = require("core/cache/cache")

---@class GPS
---@field x number
---@field y number
---@field surface_index number
local GPS = {}
GPS.__index = GPS

--- Constructor for GPS
---@param x number
---@param y number
---@param surface_index number
---@return GPS
function GPS:new(x, y, surface_index)
  local obj = setmetatable({}, self)
  obj.x = x
  obj.y = y
  obj.surface_index = surface_index
  return obj
end

--- Add a minus sign to a string if the value is negative and not zero
---@param s string
---@param n number
---@return string
local function add_minus_if_needed(s, n)
  if n < 0 and n ~= 0 then
    return "-" .. s
  end
  return s
end

--- Pad a number to at least 3 digits, preserving minus sign if negative
---@param n number
---@return string
local function pad(n)
  local floorn = math.floor(n + 0.5)
  if floorn == 0 or floorn == -0 then floorn = 0 end
  local absn = math.abs(floorn)
  local s = tostring(absn)
  if #s < Constants.settings.GPS_PAD_NUMBER then
    s = string.rep("0", 3 - #s) .. s
  end
  s = add_minus_if_needed(s, floorn)
  return s
end

--- Return the GPS string in the format xxx.yyy.s
---@return string
function GPS:to_string()
  return pad(self.x) .. "." .. pad(self.y) .. "." .. tostring(self.surface_index)
end

--- Return the surface index portion of the GPS
---@return number
function GPS:get_surface_index()
  return self.surface_index
end

--- Convert this GPS to a MapPosition
---@return MapPosition
function GPS:convert_gps_to_map_position()
  return { x = self.x, y = self.y }
end

--- Return the xxx.yyy portion as a string (no surface index)
---@return string
function GPS:coords_string()
  return pad(self.x) .. "." .. pad(self.y)
end

--- Static method: Convert a MapPosition and surface_index to a GPS string
---@param map_position MapPosition
---@param surface_index number
---@return string
function GPS.convert_map_position_to_gps(map_position, surface_index)
  return pad(map_position.x) .. "." .. pad(map_position.y) .. "." .. tostring(surface_index)
end

--- Static method: Find a Tag object by GPS string
---@param gps_string string
---@return Tag|nil
function GPS.find_tag_by_gps(gps_string)
  -- Parse the surface index from the gps string
  local surface_index = tonumber(gps_string:match("%.(%-?%d+)$"))
  if not surface_index then return nil end
  local surface_data = Cache.get_surface_data(surface_index)
  if not surface_data or not surface_data.tags then return nil end
  return surface_data.tags[gps_string]
end

return GPS