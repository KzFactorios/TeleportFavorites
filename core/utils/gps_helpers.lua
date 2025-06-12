---@diagnostic disable: undefined-global, need-check-nil, undefined-field
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
local ErrorHandler = require("core.utils.error_handler")
local padlen, BLANK_GPS = Constants.settings.GPS_PAD_NUMBER, Constants.settings.BLANK_GPS

-- Common validation patterns for standardization
local ValidationPatterns = {}

--- Standardized way to check if a tag is valid and usable
---@param tag table?
---@return boolean
function ValidationPatterns.is_valid_tag(tag)
  if not tag then return false end
  return tag.gps and type(tag.gps) == "string" and true or false
end

--- Standardized way to check if a chart tag is valid
---@param chart_tag LuaCustomChartTag?
---@return boolean
function ValidationPatterns.is_valid_chart_tag(chart_tag) 
  if not chart_tag then return false end
  return chart_tag.valid
end

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
  if not map_position then return false end

  local chunk = { x = math.floor(map_position.x / 32), y = math.floor(map_position.y / 32) }
  if not player.force.is_chunk_charted(player.surface, chunk) then
    if player and player.valid then
      player:print("[TeleportFavorites] You are trying to create a tag in uncharted territory: " ..
        gps_from_map_position(map_position, player.surface.index))
    end
    return false
  end
  
  if Helpers.is_water_tile(player.surface, map_position) or Helpers.is_space_tile(player.surface, map_position) then
    if player and player.valid then
      player:print("[TeleportFavorites] You cannot tag water or space in this interface: " ..
        gps_from_map_position(map_position, player.surface.index))
    end
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

--- Create-then-validate pattern for chart tags
--- This pattern is necessary because Factorio's API doesn't provide comprehensive
--- validation without actually creating the chart tag. Our position_can_be_tagged()
--- covers common cases, but the API may have additional internal restrictions.
--- See notes/factorio_api_validation_gaps.md for detailed rationale.
---@param player LuaPlayer
---@param chart_tag_spec table
---@return LuaCustomChartTag?, ErrorResult
local function create_and_validate_chart_tag(player, chart_tag_spec)
  ErrorHandler.debug_log("Creating chart tag for validation", {
    position = chart_tag_spec.position,
    text = chart_tag_spec.text
  })
  
  -- Create the chart tag first
  local chart_tag = player.force:add_chart_tag(player.surface, chart_tag_spec)
  
  -- Then validate using our position checker
  -- Note: We validate the created chart tag because position_can_be_tagged may not
  -- catch all Factorio API restrictions that only surface during actual creation
  if chart_tag and chart_tag.position and not position_can_be_tagged(player, chart_tag.position) then
    ErrorHandler.debug_log("Chart tag failed position validation, destroying", {
      position = chart_tag.position
    })
    chart_tag.destroy()
    return nil, ErrorHandler.error(
      ErrorHandler.ERROR_TYPES.POSITION_INVALID,
      "This location cannot be tagged. Try again or increase your teleport radius in settings.",
      { position = chart_tag_spec.position }
    )
  end
  
  -- Final validation that chart tag was created successfully
  if not chart_tag or not chart_tag.valid then
    ErrorHandler.warn_log("Chart tag creation succeeded but tag is invalid", {
      chart_tag_exists = chart_tag ~= nil,
      position = chart_tag_spec.position
    })
    return nil, ErrorHandler.error(
      ErrorHandler.ERROR_TYPES.CHART_TAG_FAILED,
      "This location cannot be tagged. Try again or increase your teleport radius in settings.",
      { position = chart_tag_spec.position }
    )
  end
  
  ErrorHandler.debug_log("Chart tag created and validated successfully")
  return chart_tag, ErrorHandler.success()
end

--- Validate and prepare context for position normalization
---@param player LuaPlayer
---@param intended_gps string
---@return table?, ErrorResult
local function validate_and_prepare_context(player, intended_gps)
  ErrorHandler.debug_log("Validating context for position normalization", {
    player_name = player and player.name,
    intended_gps = intended_gps
  })
  
  if not player or not player.valid then
    return nil, ErrorHandler.error(
      ErrorHandler.ERROR_TYPES.VALIDATION_FAILED,
      "Invalid player reference",
      { player_exists = player ~= nil }
    )
  end
  
  if not intended_gps or intended_gps == "" then
    return nil, ErrorHandler.error(
      ErrorHandler.ERROR_TYPES.VALIDATION_FAILED,
      "Invalid GPS string provided",
      { gps = intended_gps }
    )
  end

  local landing_position = map_position_from_gps(intended_gps)
  if not landing_position then
    return nil, ErrorHandler.error(
      ErrorHandler.ERROR_TYPES.GPS_PARSE_FAILED,
      "Could not parse GPS coordinates",
      { intended_gps = intended_gps }
    )
  end

  local player_settings = Settings:getPlayerSettings(player)
  local search_radius = player_settings.tp_radius_tiles or Constants.settings.DEFAULT_TELEPORT_RADIUS_TILES
  
  local context = {
    player = player,
    intended_gps = intended_gps,
    landing_position = landing_position,
    search_radius = search_radius
  }
  
  ErrorHandler.debug_log("Context validation successful", context)
  return context, ErrorHandler.success()
end

--- Find exact matches for GPS position (tag and chart_tag)
---@param context table
---@param callbacks table
---@return table?, LuaCustomChartTag?, string, boolean
local function find_exact_matches(context, callbacks)
  ErrorHandler.debug_log("Searching for exact matches", {
    intended_gps = context.intended_gps
  })
  
  local tag = callbacks.get_tag_by_gps_func and callbacks.get_tag_by_gps_func(context.intended_gps) or nil
  local adjusted_gps = context.intended_gps
  local chart_tag = nil
  local check_for_grid_snap = true

  -- Search for exact matches first - tag and chart_tag
  if ValidationPatterns.is_valid_tag(tag) and tag.gps then
    ErrorHandler.debug_log("Found exact tag match", { tag_gps = tag.gps })
    chart_tag = ValidationPatterns.is_valid_chart_tag(tag.chart_tag) and tag.chart_tag or nil
    adjusted_gps = tag.gps
    check_for_grid_snap = false
  else
    -- there is no tag so try to find a matching chart_tag in storage
    chart_tag = callbacks.get_chart_tag_by_gps_func and callbacks.get_chart_tag_by_gps_func(context.intended_gps) or nil
    if ValidationPatterns.is_valid_chart_tag(chart_tag) and chart_tag.position then
      ErrorHandler.debug_log("Found exact chart_tag match", { 
        chart_tag_position = chart_tag.position 
      })
      adjusted_gps = gps_from_map_position(chart_tag.position, context.player.surface.index)
      check_for_grid_snap = true
    end
  end
  
  return tag, chart_tag, adjusted_gps, check_for_grid_snap
end

--- Find nearby matches within search radius
---@param context table
---@param callbacks table
---@param tag table?
---@param chart_tag LuaCustomChartTag?
---@param adjusted_gps string
---@param check_for_grid_snap boolean
---@return table?, LuaCustomChartTag?, string, boolean
local function find_nearby_matches(context, callbacks, tag, chart_tag, adjusted_gps, check_for_grid_snap)
  -- if we don't have a matching chart_tag, then search for one "in the area"
  if not ValidationPatterns.is_valid_chart_tag(chart_tag) then
    ErrorHandler.debug_log("Searching for nearby matches", {
      search_radius = context.search_radius,
      landing_position = context.landing_position
    })
    
    -- find a colliding chart_tag
    local in_area_chart_tag = Helpers.position_has_colliding_tag(context.player, context.landing_position, context.search_radius)

    if ValidationPatterns.is_valid_chart_tag(in_area_chart_tag) and in_area_chart_tag.position then
      local in_area_gps = gps_from_map_position(in_area_chart_tag.position, context.player.surface.index)
      ErrorHandler.debug_log("Found nearby chart tag", {
        in_area_gps = in_area_gps,
        distance_from_intended = math.sqrt(
          (in_area_chart_tag.position.x - context.landing_position.x)^2 + 
          (in_area_chart_tag.position.y - context.landing_position.y)^2
        )
      })
      
      -- if found then see if it has a matching tag
      local in_area_tag = callbacks.get_tag_by_gps_func and callbacks.get_tag_by_gps_func(in_area_gps) or nil

      if ValidationPatterns.is_valid_tag(in_area_tag) and in_area_tag.gps then
        ErrorHandler.debug_log("Nearby chart tag has matching tag", { tag_gps = in_area_tag.gps })
        tag = in_area_tag
        chart_tag = ValidationPatterns.is_valid_chart_tag(in_area_tag.chart_tag) and in_area_tag.chart_tag or nil
        adjusted_gps = in_area_tag.gps
        check_for_grid_snap = chart_tag == nil
      else
        ErrorHandler.debug_log("Nearby chart tag has no matching tag")
        tag = nil
        chart_tag = ValidationPatterns.is_valid_chart_tag(in_area_chart_tag) and in_area_chart_tag or nil
        check_for_grid_snap = true
      end
    else
      ErrorHandler.debug_log("No nearby chart tags found")
    end
  end
  
  return tag, chart_tag, adjusted_gps, check_for_grid_snap
end

--- Handle missing or invalid chart tags by creating new ones or aligning positions
---@param context table
---@param tag table?
---@param chart_tag LuaCustomChartTag?
---@return table?, LuaCustomChartTag?, string
local function handle_grid_snap_requirements(context, tag, chart_tag)
  ErrorHandler.debug_log("Handling grid snap requirements", {
    has_tag = tag ~= nil,
    has_chart_tag = chart_tag ~= nil,
    chart_tag_valid = chart_tag and chart_tag.valid
  })
  
  -- if we have a tag and that tag.chart_tag is nil or not valid
  -- then create a new chart_tag to use, Use the tag's gps
  if tag and tag.gps and (not chart_tag or (chart_tag and not chart_tag.valid)) then
    ErrorHandler.debug_log("Creating new chart tag for existing tag")
    
    local tag_position = map_position_from_gps(tag.gps)
    if not tag_position then
      ErrorHandler.debug_log("Could not parse tag GPS coordinates", { tag_gps = tag.gps })
      return tag, chart_tag, context.intended_gps
    end
    
    local chart_tag_spec = {
      position = tag_position,
      icon = {},
      text = "tag gps: " .. tag.gps,
      last_user = context.player.name
    }

    local new_chart_tag, result = create_and_validate_chart_tag(context.player, chart_tag_spec)
    if not result.success then
      ErrorHandler.handle_error(result, context.player)
      return tag, chart_tag, context.intended_gps
    end

    -- Update the tag's chart_tag reference
    tag.chart_tag = new_chart_tag
    chart_tag = new_chart_tag
    
    if chart_tag and chart_tag.position then
      local adjusted_gps = gps_from_map_position(chart_tag.position, context.player.surface.index)
      ErrorHandler.debug_log("Successfully created chart tag for tag", { adjusted_gps = adjusted_gps })
      return tag, chart_tag, adjusted_gps
    end
    
  elseif chart_tag and chart_tag.valid and chart_tag.position then
    -- mainly we just want to get rid of any possible decimal values in the gps
    if not basic_helpers.is_whole_number(chart_tag.position.x) or not basic_helpers.is_whole_number(chart_tag.position.y) then
      ErrorHandler.debug_log("Aligning chart tag to whole number coordinates", {
        current_position = chart_tag.position
      })
      
      local x = basic_helpers.normalize_index(chart_tag.position.x)
      local y = basic_helpers.normalize_index(chart_tag.position.y)
      
      if x and y then
        local rehomed_chart_tag = Tag.rehome_chart_tag(context.player, chart_tag,
          gps_from_map_position({ x = x, y = y }, context.player.surface.index))
        if not rehomed_chart_tag then
          ErrorHandler.debug_log("Failed to rehome chart tag", {
            original_position = chart_tag.position,
            target_position = { x = x, y = y }
          })
          return tag, chart_tag, context.intended_gps
        end
        chart_tag = rehomed_chart_tag
        ErrorHandler.debug_log("Successfully aligned chart tag position")
      end
    end

    -- we now have an aligned chart_tag
    if chart_tag and chart_tag.position then
      local adjusted_gps = gps_from_map_position(chart_tag.position, context.player.surface.index)
      return tag, chart_tag, adjusted_gps
    end
    
  else
    -- we have no tag and no chart_tag
    -- try to create a temp_chart_tag at the intended location
    ErrorHandler.debug_log("Creating temporary chart tag for position validation")
    
    local intended_position = map_position_from_gps(context.intended_gps)
    if not intended_position then
      ErrorHandler.debug_log("Could not parse intended GPS coordinates", { intended_gps = context.intended_gps })
      return nil, nil, context.intended_gps
    end
    
    local chart_tag_spec = {
      position = intended_position,
      icon = {},
      text = "tag gps: " .. context.intended_gps,
      last_user = context.player.name
    }

    local temp_chart_tag, result = create_and_validate_chart_tag(context.player, chart_tag_spec)
    if not result.success then
      ErrorHandler.handle_error(result, context.player)
      return nil, nil, context.intended_gps
    end

    if temp_chart_tag and temp_chart_tag.position then
      local adjusted_gps = gps_from_map_position(temp_chart_tag.position, context.player.surface.index)
      -- destroy the temp_chart_tag - it will ultimately be created by the tag editor
      temp_chart_tag.destroy()
      
      ErrorHandler.debug_log("Temporary chart tag validation successful", { adjusted_gps = adjusted_gps })
      return nil, nil, adjusted_gps
    end
  end
  
  return tag, chart_tag, context.intended_gps
end

--- Get final position data including player favorites
---@param context table
---@param adjusted_gps string
---@param tag table?
---@param chart_tag LuaCustomChartTag?
---@param callbacks table
---@return MapPosition?, table?, LuaCustomChartTag?, table?
local function finalize_position_data(context, adjusted_gps, tag, chart_tag, callbacks)
  ErrorHandler.debug_log("Finalizing position data", {
    adjusted_gps = adjusted_gps,
    has_tag = tag ~= nil,
    has_chart_tag = chart_tag ~= nil
  })
  
  -- get player favorite if any
  local matching_player_favorite = callbacks.is_player_favorite_func and 
    callbacks.is_player_favorite_func(context.player, adjusted_gps) or nil

  local adjusted_pos = map_position_from_gps(adjusted_gps)
  if not adjusted_pos then
    ErrorHandler.debug_log("Could not parse final GPS coordinates", { adjusted_gps = adjusted_gps })
    return nil, nil, nil, nil
  end
  
  if matching_player_favorite then
    ErrorHandler.debug_log("Found matching player favorite")
  end
  
  ErrorHandler.debug_log("Position normalization completed successfully", {
    final_position = adjusted_pos,
    final_gps = adjusted_gps
  })
  
  return adjusted_pos, tag, chart_tag, matching_player_favorite
end

--- Normalize a landing position; surface may be LuaSurface, string, or index
--- This function now requires Cache functions as parameters to avoid circular dependency
--- 
--- This function has been broken down into smaller helper functions to reduce complexity
--- and improve maintainability. Each step is now clearly separated with comprehensive
--- debug logging for troubleshooting.
---@param player LuaPlayer
---@param intended_gps string
---@param get_tag_by_gps_func function
---@param is_player_favorite_func function
---@param get_chart_tag_by_gps_func function
---@return MapPosition|nil, table|nil, LuaCustomChartTag|nil, table|nil -- favorite is a table
local function normalize_landing_position(player, intended_gps, get_tag_by_gps_func, is_player_favorite_func,
                                          get_chart_tag_by_gps_func)
  ErrorHandler.debug_log("Starting position normalization", {
    player_name = player and player.name,
    intended_gps = intended_gps
  })
  
  -- Step 1: Validate and prepare context
  local context, result = validate_and_prepare_context(player, intended_gps)
  if not result.success then
    ErrorHandler.handle_error(result, player, false) -- Don't print to player for validation errors
    return nil, nil, nil, nil
  end
  
  -- Package callbacks for cleaner parameter passing
  local callbacks = {
    get_tag_by_gps_func = get_tag_by_gps_func,
    is_player_favorite_func = is_player_favorite_func,
    get_chart_tag_by_gps_func = get_chart_tag_by_gps_func
  }
    -- Step 2: Find exact matches (tag and chart_tag)
  local tag, chart_tag, adjusted_gps, check_for_grid_snap
  tag, chart_tag, adjusted_gps, check_for_grid_snap = find_exact_matches(context, callbacks)
  
  -- Step 3: Find nearby matches if no exact matches found
  tag, chart_tag, adjusted_gps, check_for_grid_snap = find_nearby_matches(
    context, callbacks, tag, chart_tag, adjusted_gps, check_for_grid_snap)
    -- Step 4: Handle grid snap requirements (create/align chart tags)
  if check_for_grid_snap then
    tag, chart_tag, adjusted_gps = handle_grid_snap_requirements(context, tag, chart_tag)
  end
  
  -- Step 5: Finalize and return results
  local adjusted_pos, matching_player_favorite
  adjusted_pos, tag, chart_tag, matching_player_favorite = finalize_position_data(
    context, adjusted_gps, tag, chart_tag, callbacks)
  
  ErrorHandler.debug_log("Position normalization completed successfully")
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
    if player and player.valid then
      player:print("[TeleportFavorites] Internal error: Cache module missing")
    end
    return nil, nil, nil, nil
  end
  return normalize_landing_position(player, intended_gps, Cache.get_tag_by_gps, Cache.get_player_favorites,
    Cache.lookups.get_chart_tag_by_gps)
end

-- Export public functions
return {
  BLANK_GPS = BLANK_GPS,
  parse_gps_string = parse_gps_string,
  gps_from_map_position = gps_from_map_position,
  map_position_from_gps = map_position_from_gps,
  get_surface_index_from_gps = get_surface_index_from_gps,
  normalize_landing_position = normalize_landing_position,
  normalize_landing_position_with_cache = normalize_landing_position_with_cache,
  parse_and_normalize_gps = parse_and_normalize_gps,
  ValidationPatterns = ValidationPatterns,
  -- Helper functions for testing/external use
  create_and_validate_chart_tag = create_and_validate_chart_tag,
  validate_and_prepare_context = validate_and_prepare_context,
  find_exact_matches = find_exact_matches,
  find_nearby_matches = find_nearby_matches,
  handle_grid_snap_requirements = handle_grid_snap_requirements,
  finalize_position_data = finalize_position_data
}
