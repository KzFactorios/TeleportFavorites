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

-- Configuration and Constants
local Constants = require("constants")

-- Core Utilities
local ErrorHandler = require("core.utils.error_handler")
local Settings = require("core.utils.settings_access")
local GameHelpers = require("core.utils.game_helpers")
local RichTextFormatter = require("core.utils.rich_text_formatter")

-- GPS and Position Handling
local GPSCore = require("core.utils.gps_core")
local gps_parser = require("core.utils.gps_parser")
local GPSChartHelpers = require("core.utils.gps_chart_helpers")
local ChartTagSpecBuilder = require("core.utils.chart_tag_spec_builder")
local PositionNormalizer = require("core.utils.position_normalizer")
local PositionValidator = require("core.utils.position_validator")

-- Tag and Cache Management
local tag_destroy_helper = require("core.tag.tag_destroy_helper")
local Lookups = require("core.cache.lookups")

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

--- Find exact matches for GPS position (tag and chart_tag). Invalidates a tag if the matching chart tag position is invalid
---@param context table
---@param callbacks table
---@return Tag?, LuaCustomChartTag? -- tag, chart_tag, adjusted_gps, check_for_grid_snap
local function find_exact_matches(context, callbacks)
  ErrorHandler.debug_log("Searching for exact matches", {
    intended_gps = context.intended_gps
  })

  local adjusted_gps = context.intended_gps
  local tag = callbacks.get_tag_by_gps_func and callbacks.get_tag_by_gps_func(adjusted_gps) or nil
  tag = GPSCore.ValidationPatterns.is_valid_tag(tag) or nil
  -- is the chart_tag aligned? Yes if it is tag.chart_tag
  local chart_tag = tag and GPSCore.ValidationPatterns.is_valid_chart_tag(tag.chart_tag) and tag.chart_tag or nil
  if not chart_tag or not chart_tag.valid then
    chart_tag = callbacks.get_chart_tag_by_gps_func and callbacks.get_chart_tag_by_gps_func(context.intended_gps) or nil
  end
    -- ensure a valid chart_tag to match the tag, if we can't get a match, then the tag should be destroyed
  -- however, it is ok for a chart_tag not to have a matching tag
  if tag and not chart_tag then
    local chart_tag_spec = ChartTagSpecBuilder.build(
      gps_parser.map_position_from_gps(adjusted_gps),
      nil,
      context.player,
      GPSCore.coords_string_from_gps(adjusted_gps)
    )

    local new_chart_tag, _ = GPSChartHelpers.create_and_validate_chart_tag(context.player, chart_tag_spec) or nil

    if new_chart_tag then
      chart_tag = new_chart_tag
      tag.chart_tag = chart_tag
    else
      -- if we can't create a chart_tag, this indicates that the tag is also invalid. delete the tag safely
      if tag_destroy_helper.destroy_tag_and_chart_tag(tag, tag.chart_tag) then
        ErrorHandler.debug_log("Existing tag is not valid and has been destroyed", {
          intended_gps = context.intended_gps
        })
        tag = nil
        chart_tag = nil
      end
    end
  end

  return tag, chart_tag
end

--- Find nearby chart_tags within search radius. also return the matching tag, if any
---@param context table
---@param callbacks table
---@return table?, LuaCustomChartTag?, string, boolean
local function find_nearby_matches(context, callbacks)
  ErrorHandler.debug_log("Searching for nearby matches", {
    search_radius = context.search_radius,
    landing_position = context.landing_position
  })

  local match_tag = nil
  -- find the nearest chart tag to the click position
  local in_area_chart_tag = GameHelpers.get_nearest_chart_tag_to_click_position(context.player,
    context.landing_position,
    context.search_radius)

  if in_area_chart_tag then
    local position = in_area_chart_tag.position

    if PositionNormalizer.needs_normalization(position) then
      -- Need to normalize this chart tag to whole numbers
      local position_pair = PositionNormalizer.create_position_pair(position)
        -- Create new chart tag at normalized position using centralized builder
      local chart_tag_spec = ChartTagSpecBuilder.build(
        position_pair.new,
        in_area_chart_tag,
        context.player
      )

      local new_chart_tag = GPSChartHelpers.safe_add_chart_tag(context.player.force, context.player.surface,
        chart_tag_spec)

      if new_chart_tag and new_chart_tag.valid then
        -- Destroy the old chart tag with fractional coordinates
        in_area_chart_tag.destroy()
        in_area_chart_tag = new_chart_tag
        -- Refresh the cache to include the new chart tag
        Lookups.invalidate_surface_chart_tags(context.player.surface)        -- Inform the player about the position normalization
        local notification_msg = RichTextFormatter.position_change_notification(
          context.player,
          new_chart_tag,
          position_pair.old,
          position_pair.new,
          context.player.surface.index
        )
        GameHelpers.player_print(context.player, notification_msg)
      end
    end

    local in_area_gps = gps_parser.gps_from_map_position(in_area_chart_tag.position)
    -- look for a matching tag
    match_tag = callbacks.get_tag_by_gps_func and callbacks.get_tag_by_gps_func(in_area_gps) or nil

    -- update context
    context.intended_gps = in_area_gps
    context.landing_position = in_area_chart_tag.position
  end

  return match_tag, in_area_chart_tag
end

--- Finalize position data and check for player favorites
---@param context table
---@param tag Tag?
---@param chart_tag LuaCustomChartTag
---@param callbacks table
---@return Tag?, LuaCustomChartTag?, table?
local function finalize_position_data(context, tag, chart_tag, callbacks)
  if not chart_tag then
    return nil, nil, nil
  end

  -- Update context with final position if it changed
  context.landing_position = chart_tag.position
  context.intended_gps = gps_parser.gps_from_map_position(chart_tag.position)

  -- Check for player favorites match
  local matching_player_favorite = callbacks.is_player_favorite_func(context.player, context.intended_gps)

  ErrorHandler.debug_log("Position normalization pipeline completed", {
    final_position = context.landing_position,
    final_gps = context.intended_gps,
    has_tag = tag ~= nil,
    has_chart_tag = chart_tag ~= nil,
    has_favorite = matching_player_favorite ~= nil
  })

  return tag, chart_tag, matching_player_favorite
end

--- Create chart tag at fallback position if no existing matches found
---@param context table
---@param callbacks table
---@return table?, LuaCustomChartTag?
local function create_fallback_chart_tag(context, callbacks)
  ErrorHandler.debug_log("Creating fallback chart tag", {
    landing_position = context.landing_position,
    search_radius = context.search_radius
  })

  local valid_pos = PositionValidator.find_valid_position(context.player, context.landing_position, context.search_radius)
  if not valid_pos then
    return nil, nil
  end

  local chart_tag_spec = ChartTagSpecBuilder.build(valid_pos, nil, context.player)
  local new_chart_tag, _ = GPSChartHelpers.create_and_validate_chart_tag(context.player, chart_tag_spec)
  
  if new_chart_tag then
    context.landing_position = new_chart_tag.position
    context.intended_gps = gps_parser.gps_from_map_position(new_chart_tag.position)
    return nil, new_chart_tag  -- No existing tag, but we have a new chart_tag
  end

  return nil, nil
end

--- Normalize a landing position using clean pipeline architecture
---@param player LuaPlayer
---@param intended_gps string
---@param get_tag_by_gps_func function
---@param is_player_favorite_func function
---@param get_chart_tag_by_gps_func function
---@return Tag|nil, LuaCustomChartTag|nil, table|nil
local function normalize_landing_position(player, intended_gps, get_tag_by_gps_func, is_player_favorite_func, get_chart_tag_by_gps_func)
  ErrorHandler.debug_log("Starting position normalization pipeline", {
    player_name = player and player.name,
    intended_gps = intended_gps
  })

  -- Pipeline Step 1: Validate and prepare context
  local context, result = validate_and_prepare_context(player, intended_gps)
  if not result.success then
    ErrorHandler.handle_error(result, player, false)
    return nil, nil, nil
  end

  local callbacks = {
    get_tag_by_gps_func = get_tag_by_gps_func,
    is_player_favorite_func = is_player_favorite_func,
    get_chart_tag_by_gps_func = get_chart_tag_by_gps_func
  }

  -- Pipeline Step 2: Find exact matches
  local tag, chart_tag = find_exact_matches(context, callbacks)

  -- Pipeline Step 3: Find nearby matches if needed
  if not chart_tag then
    tag, chart_tag = find_nearby_matches(context, callbacks)
  end

  -- Pipeline Step 4: Create fallback chart tag if needed
  if not chart_tag then
    tag, chart_tag = create_fallback_chart_tag(context, callbacks)
  end

  -- Pipeline Step 5: Validate final result
  if not chart_tag then
    ErrorHandler.debug_log("Position normalization failed - no valid position found", {
      player_name = player.name,
      intended_gps = intended_gps
    })
    return nil, nil, nil
  end

  -- Pipeline Step 6: Finalize results
  return finalize_position_data(context, tag, chart_tag, callbacks)
end

--- Wrapper function that maintains the old API for backwards compatibility
--- This requires Cache to be passed in to avoid circular dependency
---@param player LuaPlayer
---@param intended_gps string
---@param Cache table Cache module reference
---@return Tag|nil, LuaCustomChartTag|nil, table|nil
local function normalize_landing_position_with_cache(player, intended_gps, Cache)
  if not Cache then
    if player and player.valid then
      GameHelpers.player_print(player, "[TeleportFavorites] Internal error: Cache module missing")
    end
    return nil, nil, nil
  end
  return normalize_landing_position(player, intended_gps, Cache.get_tag_by_gps, Cache.is_player_favorite,
    Cache.lookups.get_chart_tag_by_gps)
end

-- Export public functions
GPSPositionNormalizer.normalize_landing_position = normalize_landing_position
GPSPositionNormalizer.normalize_landing_position_with_cache = normalize_landing_position_with_cache
GPSPositionNormalizer.validate_and_prepare_context = validate_and_prepare_context
GPSPositionNormalizer.finalize_position_data = finalize_position_data

return GPSPositionNormalizer
