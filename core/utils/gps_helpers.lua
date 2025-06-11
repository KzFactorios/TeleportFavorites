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
  local player_favorite = nil
  local search_radius = Settings:getPlayerSettings(player).teleport_radius
  local check_for_grid_snap = true

  -- Search for exact matches first
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
      if not new_chart_tag or new_chart_tag and not new_chart_tag.valid then
        error("This location cannot be tagged. Try again or increase your teleport radius in settings.")
      end

      tag.chart_tag = new_chart_tag
      chart_tag = new_chart_tag
    elseif chart_tag and chart_tag.valid then
      -- mainly we just want to get rid of any possible decimal values in the gps
      if not basic_helpers.is_whole_number(chart_tag.position.x) or not basic_helpers.is_whole_number(chart_tag.position.x) then
        local x = basic_helpers.normalize_index(chart_tag.position.x)
        local y = basic_helpers.normalize_index(chart_tag.position.y)

        -- TODO align to teleport snap grid

        Tag.rehome(chart_tag, gps_from_map_position({x, y}, player.surface.index))
      end

      -- elseif chart_tag and chart_tag.valid then
      -- verify a snapped position (whole number x,y)
      -- if not snapped
      -- rehome to a valid, snapped location
      -- if we can't create a chart_tag at that location -> error


      -- otherwise
      -- just see if a chart_tag at intended_gps, or nearby is possible - get that updated position
      -- destroy any temp chart_tag

      -- if we cannot create a chart tag - then return error -> due to invalid position
    else
      -- do nothing - we should be all set
    end


    -- find a matching player_favorite

    -- return the goods


    -- TODO ensure no water or space tile











    if existing_chart_tag and existing_chart_tag.valid and existing_chart_tag.valid == true then
      local ct_position = existing_chart_tag.position
      local ct_gps = gps_from_map_position(ct_position, player.surface.index)
      local ct_map_pos = map_position_from_gps(ct_gps)
      -- if found, ensure the chart_tag aligns to the player's snap grid


      -- REHOME if ...
      -- if the coords are not equal to whole numbers
      -- if ct_position != ct_map_pos, then rehome





      -- rewrite/rehome the chart_tag -- this will clean up any rogue chart_tags that do not have a matching tag
      -- now we have specified the chart_tag to use
      -- update adjusted_gps and chart_tag
    else
      -- try to find a chart tag within range
      -- second - if not found
      -- ensure this is a valid place to place a chart_tag
      -- leave adjusted_gps as is
      -- chart_tag remains nil

      -- if it is not a valid place, find the nearest AOK location
      --if we get the OK
      -- update values

      -- if not a valid location then return an error message
    end
  end

  -- get player favorite if any
  local player_favorite = is_player_favorite_func and is_player_favorite_func(player, adjusted_gps) or nil










  if not tag then
    if not position_can_be_tagged(player, landing_position) then return end

    chart_tag = Helpers.position_has_colliding_tag(player, landing_position, player_settings.teleport_radius)
    if not chart_tag then
      -- Use "character" entity with adjusted parameters for reliable collision detection
      -- Character entity is guaranteed to be available in all Factorio configurations
      -- Increased radius provides safety margin similar to car collision box size
      local safety_radius = player_settings.teleport_radius + 2          -- Add safety margin for vehicle-sized clearance
      local fine_precision = Constants.settings.TELEPORT_PRECISION * 0.5 -- Finer search precision

      local non_collide_position = nil
      local success, error_msg = pcall(function()
        non_collide_position = player.surface:find_non_colliding_position("character", landing_position,
          safety_radius, fine_precision)
      end)

      -- The following checks are unnecessary
      -- If we don't have a result, it just means we don't have a match

      --if not success then
      --if not non_collide_position then

      if non_collide_position ~= nil and non_collide_position ~= {} then
        -- TODO ensure that we are on our grid
        adjusted_gps = gps_from_map_position(non_collide_position, player.surface.index)
      end

      local check_normalized_position = nil
      local success2, error_msg2 = pcall(function()
        check_normalized_position = player.surface:find_non_colliding_position("character",
          { x = parsed.x, y = parsed.y },
          player_settings.teleport_radius, Constants.settings.TELEPORT_PRECISION)
      end)

      if not success2 then
        return nil -- Silent failure to avoid print issues
      end

      if not check_normalized_position then
        return nil -- The area is too dense
      end
      adjusted_gps = gps_from_map_position(check_normalized_position, player.surface.index)
    else
      adjusted_gps = gps_from_map_position(chart_tag.position, player.surface.index)
    end
  else
    adjusted_gps = tag.gps
  end



  if not adjusted_gps then
    return nil -- Could not compute the teleport coordinates
  end
  local final_position = parse_gps_string(adjusted_gps)
  if not final_position then
    return nil -- Could not parse the teleport coordinates
  end
  local favorites = get_player_favorites_func and get_player_favorites_func(player) or {}
  local player_favorite = nil
  if favorites and type(favorites) == "table" and favorites.get_favorite_by_gps then
    player_favorite = favorites:get_favorite_by_gps(adjusted_gps)
  end

  return { x = final_position.x, y = final_position.y }, tag or nil, tag and tag.chart_tag or nil, player_favorite
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
  if not Cache then error("Cache module is required for normalize_landing_position") end
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
