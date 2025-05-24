local Constants = require("constants")
local Settings = require("settings")
local Helpers = require("core.utils.Helpers")
local Cache = require("core.cache.cache")

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
  return Helpers.pad(map_position.x, padlen) ..
  "." .. Helpers.pad(map_position.y, padlen) .. "." .. tostring(surface_index)
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
  local surface_index = GPS.get_surface_index(gps) or 1
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

---@returns string, MapPosition?
function GPS.align_position_for_landing(player, position, surface)
  if not player or not player.valid or type(player.teleport) ~= "function" then
    return "[TeleportFavorites] _gps_align_ Player is missing"
  end
  if not surface then surface = player.surface end

  -- ---@field find_non_colliding_position fun(self: LuaSurface, name: string, center: MapPosition, radius: double, precision: double): MapPosition?
  if not surface or type(surface.find_non_colliding_position) ~= "function" then
    return "[TeleportFavorites] _gps_align_ Surface is missing"
  end
  -- Only allow teleport if player.character is present (Factorio API)
  if rawget(player, "character") == nil then
    return "[TeleportFavorites] _gps_align_ Player character is missing"
  end

  -- Space platform check
  if Helpers.is_on_space_platform and Helpers.is_on_space_platform(player) then
    return
    "The insurance general has determined that space platform tag placement could result in injury or death, or both, and has outlawed the practice."
  end

  -- Get settings
  local settings = Settings.getPlayerSettings and Settings:getPlayerSettings(player) or { teleport_radius = 8 }
  local teleport_radius = settings.teleport_radius or 8

  -- Use the default prototype name for collision search
  local proto_name = "character"
  -- Find a non-colliding position near the target position
  -- fun(self: LuaSurface, name: string, center: MapPosition, radius: double, precision: double): MapPosition?
  local closest_position =
      surface:find_non_colliding_position(proto_name, position, teleport_radius, 4)
  if not closest_position then
    return
    "The location you have chosen is too dense. Try another location."
  end

  -- Water tile check
  if Helpers.is_water_tile(surface, closest_position) then
    return
    "Water tiles cannot be tagged by us. Use the vanilla add tag dialog if you want to mark the location."
  end
  -- Check if the position is valid for placing the player - a radar footprint is about the same size
  -- ---@field find_non_colliding_position fun(self: LuaSurface, name: string, center: MapPosition, radius: double, precision: double): MapPosition?
  if not surface.can_place_entity
      or not surface:can_place_entity("radar", closest_position,
        Settings:getPlayerSettings(player).settings.teleport_radius) then
    return "The player cannot be placed at this location. Try another location."
  end

  return nil, closest_position
end

return GPS
