--[[
core/utils/gps_helpers.lua
TeleportFavorites Factorio Mod
-----------------------------
Helpers for parsing, normalizing, and converting GPS strings and map positions.

- Canonical GPS strings: 'xxx.yyy.s' (x/y padded, s = surface index)
- Converts between GPS strings, MapPosition tables, and vanilla [gps=x,y,s] tags
- All GPS values are always strings; helpers ensure robust validation and normalization
- Used throughout the mod for tag, favorite, and teleportation logic
]]

local helpers = require("core.utils.Helpers") -- lowercase filename
local Constants = require("constants")
local padlen, BLANK_GPS = Constants.settings.GPS_PAD_NUMBER, Constants.settings.BLANK_GPS

--- Parse a GPS string 'x.y.s' into {x, y, surface_index} or nil if invalid
---@param gps string
---@return table|nil
local function parse_gps_string(gps)
  if type(gps) ~= "string" then return nil end
  local x, y, s = gps:match("^([%d%.-]+)%.([%d%.-]+)%.([%d%.-]+)$")
  return (x and y and s) and { x = tonumber(x), y = tonumber(y), surface_index = tonumber(s) } or nil
end

--- Return canonical GPS string 'xxx.yyy.s' from map position and surface index
---@param map_position MapPosition
---@param surface_index uint
---@return string
local function gps_from_map_position(map_position, surface_index)
  return helpers.pad(map_position.x, padlen).."."..helpers.pad(map_position.y, padlen).."."..tostring(surface_index)
end

--- Convert GPS string to MapPosition {x, y} (surface not included)
---@param gps string
---@return MapPosition|nil
local function map_position_from_gps(gps)
  if gps == BLANK_GPS then return { x = 0, y = 0 } end
  local parsed = parse_gps_string(gps)
  return parsed and { x = parsed.x, y = parsed.y } or nil
end

--- Get surface index from GPS string (returns 1 if invalid)
---@param gps string
---@return uint
local function get_surface_index(gps)
  local parsed = parse_gps_string(gps)
  return parsed and parsed.surface_index or 1
end

--- Normalize a landing position; surface may be LuaSurface, string, or index
---@param player table
---@param pos MapPosition
---@param surface LuaSurface|string|number
---@return MapPosition|nil
local function normalize_landing_position(player, pos, surface)
  if not pos then return nil end
  local game_surfaces = (type(_G.game) == "table" and _G.game.surfaces) or {}
  local surface_index = type(surface) == "number" and math.floor(surface)
    or (type(surface) == "table" and surface.index)
    or (type(surface) == "string" and game_surfaces[surface] and game_surfaces[surface].index)
    or 1
  return { x = pos.x, y = pos.y, surface = surface_index }
end

--- Parse and normalize a GPS string; accepts vanilla [gps=x,y,s] or canonical format
---@param gps string
---@return string
local function parse_and_normalize_gps(gps)
  if type(gps) == "string" and gps:match("^%[gps=") then
    local x, y, s = gps:match("%[gps=(%-?%d+),(%-?%d+),(%-?%d+)%]")
    if x and y and s then
      local nx, ny, ns = tonumber(x), tonumber(y), tonumber(s)
      if nx and ny and ns then
        return gps_from_map_position({x=nx, y=ny}, math.floor(ns))
      end
    end
    return BLANK_GPS
  end
  return gps or BLANK_GPS
end

return {
  BLANK_GPS = BLANK_GPS,
  parse_gps_string = parse_gps_string,
  gps_from_map_position = gps_from_map_position,
  map_position_from_gps = map_position_from_gps,
  get_surface_index = get_surface_index,
  normalize_landing_position = normalize_landing_position,
  parse_and_normalize_gps = parse_and_normalize_gps,
}
