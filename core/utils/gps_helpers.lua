-- gps_helpers.lua
-- Shared GPS string helpers for TeleportFavorites

-- GPS String Format and Usage
--
--  - GPS values must always be strings in the format 'xxx.yyy.s', where:
--      - 'xxx' is the X coordinate (may be negative, always padded to the configured length, including sign if negative)
--      - 'yyy' is the Y coordinate (may be negative, always padded to the configured length, including sign if negative)
--      - 's' is the surface index (always an integer)
--  - Valid examples:
--      - '-000123.000456.1'
--      - '000123.-000456.1'
--      - '-000123.-000456.1'
--      - '000123.000456.1'
--  - GPS must never be a table or any other type.
--  - Use helpers in this module to convert between GPS strings and tables for internal use, but always store and pass GPS as a string.
--  - If a GPS string is not valid, helpers will return nil or a blank GPS value. Always validate GPS strings before use.
--  - If a GPS string is encountered in the vanilla '[gps=x,y,s]' format, it will be normalized to the canonical string format.
--

local Helpers = require("core.utils.helpers")
local Constants = require("constants")

local padlen = Constants.settings.GPS_PAD_NUMBER
local BLANK_GPS = "1000000.1000000.1"

--- Parse a GPS string of the form 'x.y.s' into a table {x=..., y=..., surface=...}
---@param gps string
---@return table|nil
local function parse_gps_string(gps)
  if type(gps) ~= "string" then return nil end
  local x, y, s = string.match(gps, "^([%d%.-]+)%.([%d%.-]+)%.([%d%.-]+)$")
  if not x or not y or not s then return nil end
  return { x = tonumber(x), y = tonumber(y), surface_index = tonumber(s) }
end

-- Add tests for parse_gps_string edge cases:
-- 1. gps is nil
-- 2. gps is not a string
-- 3. gps is a string but not matching the pattern
-- 4. gps is a valid string

--- Return the GPS string in the format xxx.yyy.s
---@param map_position MapPosition
---@param surface_index uint
---@return string
local function gps_from_map_position(map_position, surface_index)
  return Helpers.pad(map_position.x, padlen) ..
    "." .. Helpers.pad(map_position.y, padlen) .. "." .. tostring(surface_index)
end

--- Convert a gps string to a MapPosition {x,y}. Surface index is not included
---@param gps string
---@return MapPosition|nil
local function map_position_from_gps(gps)
  if gps == BLANK_GPS then
    return { x = 0, y = 0 }
  end
  local parsed = parse_gps_string(gps)
  if not parsed then return nil end
  return { x = parsed.x, y = parsed.y }
end

--- Get the surface index from a gps string
---@param gps string
---@return uint
local function get_surface_index(gps)
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
local function normalize_landing_position(player, pos, surface)
  if not pos then return nil end
  ---@diagnostic disable-next-line: undefined-global
  local game_surfaces = (type(game) == "table" and game.surfaces) or {}
  local surface_index = 1
  if type(surface) == "number" then
    surface_index = math.floor(surface)
  elseif type(surface) == "table" and surface.index then
    surface_index = surface.index
  elseif type(surface) == "string" then
    local surf = game_surfaces[surface]
    surface_index = surf and surf.index or 1
  end
  return { x = pos.x, y = pos.y, surface = surface_index }
end

return {
  BLANK_GPS = BLANK_GPS,
  parse_gps_string = parse_gps_string,
  gps_from_map_position = gps_from_map_position,
  map_position_from_gps = map_position_from_gps,
  get_surface_index = get_surface_index,
  normalize_landing_position = normalize_landing_position,
}
