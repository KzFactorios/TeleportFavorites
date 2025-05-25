local Constants = require("constants")
local Settings = require("settings")
local Helpers = require("core.utils.helpers")

local GPS = {}

local padlen = Constants.settings.GPS_PAD_NUMBER
local BLANK_GPS = "1000000.1000000.1"

--- Parse a GPS string of the form 'x.y.s' into a table {x=..., y=..., surface=...}
---@param gps string
---@return table|nil
local function parse_gps_string(gps)
  local x, y, s = string.match(gps, "^([%d%.-]+)%.([%d%.-]+)%.([%d%.-]+)$")
  if not x or not y or not s then return nil end
  return { x = tonumber(x), y = tonumber(y), surface_index = tonumber(s) }
end

--- Return the GPS string in the format xxx.yyy.s
---@param map_position MapPosition
---@param surface_index uint
---@return string
function GPS.gps_from_map_position(map_position, surface_index)
  return Helpers.pad(map_position.x, padlen) ..
  "." .. Helpers.pad(map_position.y, padlen) .. "." .. tostring(surface_index)
end

--- Convert a gps string to a MapPosition {x,y}. Surface index is not included
---@param gps string
---@return MapPosition|nil
function GPS.map_position_from_gps(gps)
  if gps == BLANK_GPS then
    return { x = 0, y = 0 }
  end
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

-- Lazy require to break circular dependency with core.cache.cache
local function get_cache()
  return require("core.cache.cache")
end

--- Find a Tag object by GPS string
---@param gps string
---@return Tag|nil
function GPS.find_tag_by_gps(gps)
  return get_cache().get_tag_by_gps(gps)
end

--- Get the surface index from a gps string
---@param gps string
---@return uint
function GPS.get_surface_index(gps)
  local parsed = parse_gps_string(gps)
  if parsed then
    return parsed.surface_index
  else
    return 1
  end
end

--- Normalize a landing position, accepting surface as LuaSurface, string, or index
---@param player table
---@param pos MapPosition
---@param surface LuaSurface|string|number
---@return MapPosition|nil
function GPS.normalize_landing_position(player, pos, surface)
  if not pos then return nil end

  -- Mock or fallback for `game` global in non-Factorio runtime
---@diagnostic disable-next-line: undefined-global
  local game_surfaces = (type(game) == "table" and game.surfaces) or {}

  -- Accept surface as index, LuaSurface, or string
  local surface_index = 1
  if type(surface) == "number" then
    surface_index = math.floor(surface) -- Ensure it's an integer
  elseif type(surface) == "table" and surface.index then
    surface_index = surface.index
  elseif type(surface) == "string" then
    local surf = game_surfaces[surface]
    surface_index = surf and surf.index or 1
  end

  return { x = pos.x, y = pos.y, surface = surface_index }
end

return GPS
