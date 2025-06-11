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

-- DO NOT require core.gps.gps here to avoid circular dependency
-- local GPS = require("core.gps.gps")

local basic_helpers = require("core.utils.basic_helpers")
local Helpers = require("core.utils.helpers_suite")
local Constants = require("constants")
local Settings = require("settings")
local padlen, BLANK_GPS = Constants.settings.GPS_PAD_NUMBER, Constants.settings.BLANK_GPS

--- Parse a GPS string 'x.y.s' into {x, y, surface_index} or nil if invalid
---@param gps string
---@return table|nil
local function parse_gps_string(gps)
  if type(gps) ~= "string" then return nil end
  if gps == BLANK_GPS then return { x = 0, y = 0, s = -1 } end

  local x, y, s = gps:match("^(%-?%d+)%.(%-?%d+)%.(%d+)$")
  if not x or not y or not s then return nil end
  local parsed_x, parsed_y, parsed_s = tonumber(x), tonumber(y), tonumber(s)
  if not parsed_x or not parsed_y or not parsed_s then return nil end
  local ret = {
    x = basic_helpers.normalize_index(parsed_x),
    y = basic_helpers.normalize_index(parsed_y),
    s = basic_helpers.normalize_index(parsed_s)
  }
  return ret
end

--- Return canonical GPS string 'xxx.yyy.s' from map position and surface index
---@param map_position MapPosition
---@param surface_index uint
---@return string
local function gps_from_map_position(map_position, surface_index)
  return basic_helpers.pad(map_position.x, padlen) ..
      "." .. basic_helpers.pad(map_position.y, padlen) ..
      "." .. tostring(surface_index)
end

-- Local function to check if a position can be tagged (moved from position_helpers to break circular dependency)
local function position_can_be_tagged(player, map_position)
  if not (player and player.force and player.surface and player.force.is_chunk_charted) then return false end
  local chunk = { x = math.floor(map_position.x / 32), y = math.floor(map_position.y / 32) }
  if not player.force:is_chunk_charted(player.surface, chunk) then
    player:print("[TeleportFavorites] You are trying to create a tag in uncharted territory: " ..
    gps_from_map_position(map_position, player.surface.index))
    return false
  end
  if Helpers.is_water_tile(player.surface, map_position) or Helpers.is_space_tile(player.surface, map_position) then
    player:print("[TeleportFavorites] You cannot tag water or space in this interface: " ..
    gps_from_map_position(map_position, player.surface.index))
    return false
  end
  return true
end

--- Convert GPS string to MapPosition {x, y} (surface not included)
---@param gps string
---@return MapPosition?
local function map_position_from_gps(gps)
  if gps == BLANK_GPS then return nil end
  local parsed = parse_gps_string(gps)
  return parsed and { x = parsed.x, y = parsed.y } or nil
end

--- Get surface index from GPS string (returns nil if invalid)
---@param gps string
---@return uint?
local function get_surface_index_from_gps(gps)
  if gps == BLANK_GPS then return nil end
  local parsed = parse_gps_string(gps)
  return parsed and parsed.s or nil
end

---TODO REVIEW
--- Normalize a landing position; surface may be LuaSurface, string, or index
--- This function now requires Cache functions as parameters to avoid circular dependency
---@param player LuaPlayer
---@param intended_gps string
---@param get_tag_by_gps_func function
---@param get_player_favorites_func function
---@return MapPosition|nil, table|nil, LuaCustomChartTag|nil, table|nil
local function normalize_landing_position(player, intended_gps, get_tag_by_gps_func, get_player_favorites_func)
  if not player or not intended_gps or intended_gps == "" then return nil end

  local landing_position = map_position_from_gps(intended_gps)
  if not landing_position then return nil end

  local adjusted_gps = nil
  local chart_tag = nil
  local tag = get_tag_by_gps_func and get_tag_by_gps_func(intended_gps) or nil
  
  if not tag then
    if not position_can_be_tagged(player, landing_position) then return end
    local player_settings = Settings:getPlayerSettings(player)
    chart_tag = Helpers.position_has_colliding_tag(player, landing_position, player_settings.teleport_radius)
    if not chart_tag then
      local non_collide_position = player.surface:find_non_colliding_position("car", landing_position,
        player_settings.teleport_radius, Constants.settings.TELEPORT_PRECISION)
      if not non_collide_position then
        player:print(
          "There is no available teleport landing position within your radius. Choose another location or adjust your teleport radius.")
        return
      end      
      local gps_str = gps_from_map_position(non_collide_position, player.surface.index)
      local parsed = parse_gps_string(gps_str)
      if not parsed then
        player:print("Could not parse GPS coordinates for landing position")
        return
      end
      local check_normalized_position = player.surface:find_non_colliding_position("car", { x = parsed.x, y = parsed.y },
        player_settings.teleport_radius, Constants.settings.TELEPORT_PRECISION)
      if not check_normalized_position then
        player:print(
          "The area you are trying to land is too dense. Choose another location or adjust your teleport radius.")
        return
      end      
      adjusted_gps = gps_from_map_position(check_normalized_position, player.surface.index)
    else
      adjusted_gps = gps_from_map_position(chart_tag.position, player.surface.index)
    end
  else
    adjusted_gps = tag.gps
  end

  if not adjusted_gps then
    player:print("Could not compute the teleport coordinates")
    return nil
  end  
  
  local final_position = parse_gps_string(adjusted_gps)
  if not final_position then
    player:print("Could not parse the teleport coordinates")
    return nil
  end
  local favorites = get_player_favorites_func and get_player_favorites_func(player) or {}
  local player_favorite = nil
  if favorites and type(favorites) == "table" and favorites.get_favorite_by_gps then
    player_favorite = favorites:get_favorite_by_gps(adjusted_gps)
  end

  return { x = final_position.x, y = final_position.y }, tag or nil, tag and tag.chart_tag or nil, player_favorite
end

---TODO REVIEW
--- Parse and normalize a GPS string; accepts vanilla [gps=x,y,s] or canonical format
---@param gps string
---@return string
local function parse_and_normalize_gps(gps)  if type(gps) == "string" and gps:match("^%[gps=") then
    local x, y, s = gps:match("%[gps=(%-?%d+),(%-?%d+),(%-?%d+)%]")
    if x and y and s then
      local nx, ny, ns = basic_helpers.normalize_index(x), basic_helpers.normalize_index(y), tonumber(s)
      if nx and ny and ns then
        return gps_from_map_position({ x = nx, y = ny }, math.floor(ns))
      end
    end
    return BLANK_GPS
  end
  return gps or BLANK_GPS
end

--- Wrapper function that maintains the old API for backwards compatibility
--- This requires Cache to be passed in to avoid circular dependency
---@param player LuaPlayer
---@param intended_gps string
---@param Cache table Cache module reference
---@return MapPosition|nil, table|nil, LuaCustomChartTag|nil, table|nil
local function normalize_landing_position_with_cache(player, intended_gps, Cache)
  if not Cache then error("Cache module is required for normalize_landing_position") end
  return normalize_landing_position(player, intended_gps, Cache.get_tag_by_gps, Cache.get_player_favorites)
end

return {
  BLANK_GPS = BLANK_GPS,
  parse_gps_string = parse_gps_string,
  gps_from_map_position = gps_from_map_position,
  map_position_from_gps = map_position_from_gps,
  get_surface_index_from_gps = get_surface_index_from_gps,
  normalize_landing_position = normalize_landing_position_with_cache,
  parse_and_normalize_gps = parse_and_normalize_gps,
}
