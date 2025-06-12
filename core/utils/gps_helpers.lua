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
local Tag = require("core.tag.tag")
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
  if not player.force.is_chunk_charted(player.surface, chunk) then
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
---@param is_player_favorite_func function
---@param get_chart_tag_by_gps_func function
---@return MapPosition|nil, Tag|nil, LuaCustomChartTag|nil, table|nil -- favorite is a table
local function normalize_landing_position(player, intended_gps, get_tag_by_gps_func, is_player_favorite_func,
                                          get_chart_tag_by_gps_func)
  if not player or not intended_gps or intended_gps == "" then return nil end

  local landing_position = map_position_from_gps(intended_gps)
  if not landing_position then return nil end

  local tag = get_tag_by_gps_func and get_tag_by_gps_func(intended_gps) or nil
  local adjusted_gps = intended_gps
  local chart_tag = nil
  local search_radius = Settings.getPlayerSettings(player).teleport_radius
  local check_for_grid_snap = true

  -- Search for exact matches first - tag and chart_tag
  if tag ~= nil and tag ~= {} then
    chart_tag = tag.chart_tag.valid and tag.chart_tag or nil
    adjusted_gps = tag.gps
    check_for_grid_snap = false
  else
    -- there is no tag so try to find a matching chart_tag in storage
    chart_tag = get_chart_tag_by_gps_func and get_chart_tag_by_gps_func(intended_gps) or nil
    if chart_tag and chart_tag.valid then
      adjusted_gps = gps_from_map_position(chart_tag.position, player.surface.index)
      check_for_grid_snap = true
    end
  end

  -- if we don't have a matching chart_tag, then search for one "in the area"
  if not chart_tag or chart_tag.valid ~= true then
    -- find a colliding chart_tag
    local in_area_chart_tag = Helpers.position_has_colliding_tag(player, landing_position, search_radius)

    if in_area_chart_tag and in_area_chart_tag.valid then
      local in_area_gps = gps_from_map_position(in_area_chart_tag.position, player.surface.index)
      -- if found then see if it has a matching tag
      local in_area_tag = get_tag_by_gps_func and get_tag_by_gps_func(in_area_gps) or nil

      if in_area_tag ~= nil and in_area_tag ~= {} then
        tag = in_area_tag
        chart_tag = in_area_tag.chart_tag.valid == true and in_area_tag.chart_tag or nil
        adjusted_gps = in_area_tag.gps
        check_for_grid_snap = chart_tag == nil
      else
        tag = nil
        chart_tag = in_area_chart_tag.valid == true and in_area_chart_tag or nil
        check_for_grid_snap = true
      end
    end
  end


  -- if it is warranted to check for a valid snapped location...
  if check_for_grid_snap == true then
    -- if we have a tag and that tag.chart_tag is nil or not valid
    -- then create a new chart_tag to use, Use the tag's gps
    -- if we can't create a chart_tag at that location -> error
    if tag and not chart_tag or not chart_tag.valid then
      -- code to create a new chart_tag
      local chart_tag_spec = {
        position = map_position_from_gps(tag.gps),
        icon = {},
        text = "tag gps: " .. tag.gps,
        last_user = player.name -- TODO this is not necessarily the original owner
      }

      local new_chart_tag = player.force:add_chart_tag(player.surface, chart_tag_spec)
      if not position_can_be_tagged(player, new_chart_tag) then
        new_chart_tag.destroy()
        new_chart_tag = nil
      end      if not new_chart_tag or new_chart_tag and not new_chart_tag.valid then
        -- TODO get rid of the matching tag too, because we can't place a chart_tag here?
        -- TODO leave the tag alone, it may be in move mode?
        player:print("[TeleportFavorites] This location cannot be tagged. Try again or increase your teleport radius in settings.")
        return nil, nil, nil, nil
      end

      tag.chart_tag = new_chart_tag
      chart_tag = new_chart_tag
    elseif chart_tag and chart_tag.valid then
      -- mainly we just want to get rid of any possible decimal values in the gps
      if not basic_helpers.is_whole_number(chart_tag.position.x) or not basic_helpers.is_whole_number(chart_tag.position.y) then
        local x = basic_helpers.normalize_index(chart_tag.position.x)
        local y = basic_helpers.normalize_index(chart_tag.position.y)        -- TODO align to teleport snap grid - not sure this is 100% necessary - just moving to whole numbers may do the intended job
        
        local rehomed_chart_tag = Tag.rehome_chart_tag(player, chart_tag,
          gps_from_map_position({ x = x, y = y }, player.surface.index))
        if not rehomed_chart_tag then
          player:print("[TeleportFavorites] This location cannot be tagged. Try again or increase your teleport radius in settings.")
          return nil, nil, nil, nil
        end
        chart_tag = rehomed_chart_tag
      end

      -- we now have an aligned chart_tag
      adjusted_gps = gps_from_map_position(chart_tag.position, player.surface.index)
    else
      -- we have not tag and no chart_tag
      -- try to create a temp_chart_tag at the intended location
      -- if we fail then error
      local chart_tag_spec = {
        position = map_position_from_gps(adjusted_gps),
        icon = {},
        text = "tag gps: " .. adjusted_gps,
        last_user = player.name -- TODO this is not necessarily the original owner
      }

      local temp_chart_tag = player.force:add_chart_tag(player.surface, chart_tag_spec)
      if not position_can_be_tagged(player, temp_chart_tag and temp_chart_tag.position or nil) then
        temp_chart_tag.destroy()
        temp_chart_tag = nil
      end      if not temp_chart_tag or not temp_chart_tag.valid then
        player:print("[TeleportFavorites] This location cannot be tagged. Try again or increase your teleport radius in settings.")
        return nil, nil, nil, nil
      end

      adjusted_gps = gps_from_map_position(temp_chart_tag.position, player.surface.index)
      -- destroy the temp_chart_tag - it will ultimately be created by the tag editor
      temp_chart_tag.destroy()

      tag = nil
      chart_tag = nil
    end
  end -- check_for_grid_snap

  -- get player favorite if any
  local matching_player_favorite = is_player_favorite_func and is_player_favorite_func(player, adjusted_gps) or nil

  local adjusted_pos = map_position_from_gps(adjusted_gps)

  -- return the goods: the normalized map position, matching_tag, matching_chart_tag, matching_player_favorite
  return adjusted_pos, tag, chart_tag, matching_player_favorite
end

--- Parse and normalize a GPS string; accepts vanilla [gps=x,y,s] or canonical format
---@param gps string
---@return string
local function parse_and_normalize_gps(gps)
  if type(gps) == "string" and gps:match("^%[gps=") then
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
  if not Cache then 
    if player then
      player:print("[TeleportFavorites] Internal error: Cache module missing")
    end
    return nil, nil, nil, nil
  end
  return normalize_landing_position(player, intended_gps, Cache.get_tag_by_gps, Cache.get_player_favorites,
    Cache.lookups.get_chart_tag_by_gps)
end

return {
  BLANK_GPS = BLANK_GPS,
  parse_gps_string = parse_gps_string,
  gps_from_map_position = gps_from_map_position,
  map_position_from_gps = map_position_from_gps,
  get_surface_index_from_gps = get_surface_index_from_gps,
  normalize_landing_position = normalize_landing_position,
  normalize_landing_position_with_cache = normalize_landing_position_with_cache,
  parse_and_normalize_gps = parse_and_normalize_gps,
}
