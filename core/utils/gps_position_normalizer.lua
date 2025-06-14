---@diagnostic disable
--[[
core/utils/gps_position_normalizer.lua
TeleportFavorites Factorio Mod
-----------------------------
Complex position normalization logic for GPS coordinates.

- Finds exact and nearby matches for GPS positions
- Handles grid snap requirements and chart tag alignment
- Manages tag/chart_tag/favorite relationships
- Provides the main normalize_landing_position functionality
- Validates positions to avoid water/space tiles
]]

local Helpers = require("core.utils.helpers_suite")
local Settings = require("core.utils.settings_access")
local Constants = require("constants")
local ErrorHandler = require("core.utils.error_handler")
local basic_helpers = require("core.utils.basic_helpers")
local GPSCore = require("core.utils.gps_core")
local GPSChartHelpers = require("core.utils.gps_chart_helpers")
local PositionValidator = require("core.utils.position_validator")
local GameHelpers = require("core.utils.game_helpers")

-- Dev environment detection removed - functionality no longer needed

---@class GPSPositionNormalizer
local GPSPositionNormalizer = {}


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

  local landing_position = GPSCore.map_position_from_gps(intended_gps)
  if not landing_position then
    return nil, ErrorHandler.error(
      ErrorHandler.ERROR_TYPES.GPS_PARSE_FAILED,
      "Could not parse GPS coordinates",
      { intended_gps = intended_gps }
    )
  end
  local player_settings = Settings:getPlayerSettings(player)
  local search_radius = player_settings.teleport_radius or Constants.settings.TELEPORT_RADIUS_DEFAULT
  
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
  if GPSCore.ValidationPatterns.is_valid_tag(tag) and tag.gps then
    ErrorHandler.debug_log("Found exact tag match", { tag_gps = tag.gps })
    chart_tag = GPSCore.ValidationPatterns.is_valid_chart_tag(tag.chart_tag) and tag.chart_tag or nil
    adjusted_gps = tag.gps
    check_for_grid_snap = false
  else
    -- there is no tag so try to find a matching chart_tag in storage
    chart_tag = callbacks.get_chart_tag_by_gps_func and callbacks.get_chart_tag_by_gps_func(context.intended_gps) or nil
    if GPSCore.ValidationPatterns.is_valid_chart_tag(chart_tag) and chart_tag.position then
      ErrorHandler.debug_log("Found exact chart_tag match", { 
        chart_tag_position = chart_tag.position 
      })
      adjusted_gps = GPSCore.gps_from_map_position(chart_tag.position, context.player.surface.index)
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
  if not GPSCore.ValidationPatterns.is_valid_chart_tag(chart_tag) then
    ErrorHandler.debug_log("Searching for nearby matches", {
      search_radius = context.search_radius,
      landing_position = context.landing_position
    })
      -- find the nearest chart tag to the click position
    local in_area_chart_tag = Helpers.get_nearest_tag_to_click_position(context.player, context.landing_position, context.search_radius)
    if GPSCore.ValidationPatterns.is_valid_chart_tag(in_area_chart_tag) and in_area_chart_tag.position then
      local in_area_gps = GPSCore.gps_from_map_position(in_area_chart_tag.position, context.player.surface.index)
      ErrorHandler.debug_log("Found nearby chart tag", {
        in_area_gps = in_area_gps,
        distance_from_intended = math.sqrt(
          (in_area_chart_tag.position.x - context.landing_position.x)^2 + 
          (in_area_chart_tag.position.y - context.landing_position.y)^2
        )
      })
      
      -- if found then see if it has a matching tag
      local in_area_tag = callbacks.get_tag_by_gps_func and callbacks.get_tag_by_gps_func(in_area_gps) or nil

      if GPSCore.ValidationPatterns.is_valid_tag(in_area_tag) and in_area_tag.gps then
        ErrorHandler.debug_log("Nearby chart tag has matching tag", { tag_gps = in_area_tag.gps })
        tag = in_area_tag
        chart_tag = GPSCore.ValidationPatterns.is_valid_chart_tag(in_area_tag.chart_tag) and in_area_tag.chart_tag or nil
        adjusted_gps = in_area_tag.gps
        check_for_grid_snap = chart_tag == nil
      else
        ErrorHandler.debug_log("Nearby chart tag has no matching tag")
        tag = nil
        chart_tag = GPSCore.ValidationPatterns.is_valid_chart_tag(in_area_chart_tag) and in_area_chart_tag or nil
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
    
    local tag_position = GPSCore.map_position_from_gps(tag.gps)
    if not tag_position then
      ErrorHandler.debug_log("Could not parse tag GPS coordinates", { tag_gps = tag.gps })
      return tag, chart_tag, context.intended_gps
    end
    
    -- Validate position is not on water or space
    if not PositionValidator.is_valid_tag_position(context.player, tag_position, true) then
      -- Find valid position nearby
      local valid_position = PositionValidator.find_valid_position(
        context.player, tag_position, context.search_radius)
      
      -- If found valid position, use it instead
      if valid_position then
        tag_position = valid_position
        tag.gps = GPSCore.gps_from_map_position(valid_position, context.player.surface.index)
        ErrorHandler.debug_log("Fixed invalid position", { 
          original_position = tag_position,
          new_position = valid_position 
        })
      else
        -- Could not find valid position
        ErrorHandler.debug_log("Could not find valid position, will prompt user later")
      end
    end
      local chart_tag_spec = {
      position = tag_position,
      text = "tag gps: " .. tag.gps,
      last_user = context.player.name
    }

    local new_chart_tag, result = GPSChartHelpers.create_and_validate_chart_tag(context.player, chart_tag_spec)
    if not result.success then
      ErrorHandler.handle_error(result, context.player)
      return tag, chart_tag, context.intended_gps
    end

    -- Update the tag's chart_tag reference
    tag.chart_tag = new_chart_tag
    chart_tag = new_chart_tag
    
    if chart_tag and chart_tag.position then
      local adjusted_gps = GPSCore.gps_from_map_position(chart_tag.position, context.player.surface.index)
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
        -- Check if normalized position is valid
        local normalized_pos = {x = x, y = y}
        if not PositionValidator.is_valid_tag_position(context.player, normalized_pos, true) then
          -- Find valid position nearby
          local valid_position = PositionValidator.find_valid_position(
            context.player, normalized_pos, context.search_radius)
          
          -- If found valid position, use it
          if valid_position then
            x = valid_position.x
            y = valid_position.y
            ErrorHandler.debug_log("Fixed invalid position during normalization", { 
              original_position = normalized_pos,
              new_position = valid_position 
            })
          end
        end
        
        local rehomed_chart_tag = GPSChartHelpers.align_chart_tag_position(context.player, chart_tag)
        if not rehomed_chart_tag then
          ErrorHandler.debug_log("Failed to align chart tag", {
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
      local adjusted_gps = GPSCore.gps_from_map_position(chart_tag.position, context.player.surface.index)
      return tag, chart_tag, adjusted_gps
    end
    
  else
    -- we have no tag and no chart_tag
    -- try to create a temp_chart_tag at the intended location
    ErrorHandler.debug_log("Creating temporary chart tag for position validation")
    
    local intended_position = GPSCore.map_position_from_gps(context.intended_gps)
    if not intended_position then
      ErrorHandler.debug_log("Could not parse intended GPS coordinates", { intended_gps = context.intended_gps })
      return nil, nil, context.intended_gps
    end
      -- Ensure position is valid (not water/space)
    if not PositionValidator.is_valid_tag_position(context.player, intended_position, true) then
      -- Find valid position nearby
      local valid_position = PositionValidator.find_valid_position(
        context.player, intended_position, context.search_radius)
      
      -- If found valid position, use it
      if valid_position then
        intended_position = valid_position
        ErrorHandler.debug_log("Fixed invalid position for new chart tag", { 
          original_position = intended_position,
          new_position = valid_position 
        })
      end
    end
    
    local chart_tag_spec = {
      position = intended_position,
      text = "tag gps: " .. context.intended_gps,
      last_user = context.player.name
    }

    local temp_chart_tag, result = GPSChartHelpers.create_and_validate_chart_tag(context.player, chart_tag_spec)
    if not result.success then
      ErrorHandler.handle_error(result, context.player)
      return nil, nil, context.intended_gps
    end

    if temp_chart_tag and temp_chart_tag.position then
      local adjusted_gps = GPSCore.gps_from_map_position(temp_chart_tag.position, context.player.surface.index)
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
    callbacks.is_player_favorite_func(context.player, adjusted_gps)

  local adjusted_pos = GPSCore.map_position_from_gps(adjusted_gps)
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
      local snap_tag, snap_chart_tag, snap_gps = handle_grid_snap_requirements(context, tag, chart_tag)
      -- Use returned values if they exist, otherwise keep original values
      tag = snap_tag or tag
      chart_tag = snap_chart_tag or chart_tag  
      adjusted_gps = snap_gps or adjusted_gps
    end
    
    -- Check if the position is on water or space
    local map_position = GPSCore.map_position_from_gps(adjusted_gps)
    if map_position and not PositionValidator.is_valid_tag_position(player, map_position, true) then
      -- Try to find valid position nearby
      local valid_position = PositionValidator.find_valid_position(player, map_position, context.search_radius)
      if valid_position then
        adjusted_gps = GPSCore.gps_from_map_position(valid_position, player.surface.index)
        ErrorHandler.debug_log("Adjusted position to avoid water/space", { 
          new_position = valid_position,
          new_gps = adjusted_gps
        })
      else
        -- Could not find valid position
        ErrorHandler.debug_log("Could not find valid position nearby")
        -- Return nil to indicate invalid position
        return nil, nil, nil, nil
      end
    end
      -- Step 5: Finalize and return results
    local adjusted_pos, matching_player_favorite
    adjusted_pos, tag, chart_tag, matching_player_favorite = finalize_position_data(
      context, adjusted_gps, tag, chart_tag, callbacks)
    
    ErrorHandler.debug_log("Position normalization completed successfully")
    return adjusted_pos, tag, chart_tag, matching_player_favorite
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
      GameHelpers.player_print(player, "[TeleportFavorites] Internal error: Cache module missing")
    end
    return nil, nil, nil, nil
  end
  return normalize_landing_position(player, intended_gps, Cache.get_tag_by_gps, Cache.is_player_favorite,
    Cache.lookups.get_chart_tag_by_gps)
end

-- Export public functions
GPSPositionNormalizer.normalize_landing_position = normalize_landing_position
GPSPositionNormalizer.normalize_landing_position_with_cache = normalize_landing_position_with_cache
GPSPositionNormalizer.validate_and_prepare_context = validate_and_prepare_context
GPSPositionNormalizer.find_exact_matches = find_exact_matches
GPSPositionNormalizer.find_nearby_matches = find_nearby_matches
GPSPositionNormalizer.handle_grid_snap_requirements = handle_grid_snap_requirements
GPSPositionNormalizer.finalize_position_data = finalize_position_data

return GPSPositionNormalizer
