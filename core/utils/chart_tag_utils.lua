

-- core/utils/chart_tag_utils.lua
-- TeleportFavorites Factorio Mod
-- Unified chart tag utilities for all chart tag operations.
-- Provides multiplayer-safe helpers for chart tag detection, cache management, and safe creation.
-- Integrates with GPSUtils, ErrorHandler, and Cache for robust surface-aware operations.
--
-- API:
--   ChartTagUtils.find_closest_chart_tag_to_position(player, cursor_position): Find chart tag at a position.
--   ChartTagUtils.safe_add_chart_tag(force, surface, spec, player): Safely create or update a chart tag.

local ErrorHandler = require("core.utils.error_handler")
local GPSUtils = require("core.utils.gps_utils")
local Cache = require("core.cache.cache")
local BasicHelpers = require("core.utils.basic_helpers")

---@class ChartTagUtils
local ChartTagUtils = {}

-- Cache for last clicked chart tags per player
local last_clicked_chart_tags = {}

--- Find chart tag at a specific position
---@param player LuaPlayer Player context
---@param cursor_position MapPosition Position to check
---@return LuaCustomChartTag? chart_tag Found chart tag or nil
function ChartTagUtils.find_closest_chart_tag_to_position(player, cursor_position)
  if not BasicHelpers.is_valid_player(player) or not cursor_position then return nil end

  -- Only detect clicks while in map mode
  if player.render_mode ~= defines.render_mode.chart then
  end
  -- Get surface index from player's current surface
  local surface_index = player.surface and player.surface.index or nil
  if not surface_index then return nil end

  -- First check the cache to see if we have chart tags loaded
  local force_tags = Cache.Lookups.get_chart_tag_cache(surface_index)

  -- If cache appears empty, try invalidating it once to trigger refresh
  if not force_tags or #force_tags == 0 then
    Cache.Lookups.invalidate_surface_chart_tags(surface_index)
    force_tags = Cache.Lookups.get_chart_tag_cache(surface_index)
  end

  -- If still no tags found, there genuinely are no chart tags on this surface
  if not force_tags or #force_tags == 0 then
    return nil
  end
  
  -- Get click radius from player settings
  local click_radius = Cache.Settings.get_chart_tag_click_radius(player)

  -- Initialize min_distance and closest_tag
  local min_distance = math.huge
  local closest_tag = nil
  -- Find the closest chart tag within detection radius
  for _, tag in pairs(force_tags) do
    if tag and tag.valid then
      local dx = math.abs(tag.position.x - cursor_position.x)
      local dy = math.abs(tag.position.y - cursor_position.y)
      -- Rectangle search: check if within radius bounds for both X and Y
      if dx <= click_radius and dy <= click_radius then
        -- Calculate distance for finding closest tag within rectangle
        local distance = math.sqrt(dx * dx + dy * dy)
        if distance < min_distance then
          min_distance = distance
          closest_tag = tag
        end
      end
    end
  end

  return closest_tag
end

--- Safe wrapper for chart tag creation with comprehensive error handling and collision detection
---@param force LuaForce The force that will own the chart tag
---@param surface LuaSurface The surface where the tag will be placed
---@param spec table Chart tag specification table (position, text, etc.)
---@param player LuaPlayer? Player context for collision notifications
---@return LuaCustomChartTag|nil chart_tag The created chart tag or nil if failed
function ChartTagUtils.safe_add_chart_tag(force, surface, spec, player)
  -- Input validation
  if not force or not surface or not spec then
    ErrorHandler.debug_log("Invalid arguments to safe_add_chart_tag", {
      has_force = force ~= nil,
      has_surface = surface ~= nil,
      has_spec = spec ~= nil
    })
    return nil
  end

  -- Validate position
  if not spec.position or type(spec.position.x) ~= "number" or type(spec.position.y) ~= "number" then
    ErrorHandler.debug_log("Invalid position in chart tag spec", {
      position = spec.position
    })
    return nil
  end
  -- Natural position system: check for existing chart tag via cache
  local surface_index = tonumber(surface.index) or 1
  local gps = GPSUtils.gps_from_map_position(spec.position, surface_index)
  -- Use existing chart tag reuse system instead of collision detection
  local existing_chart_tag = nil
  if player and player.valid then
    existing_chart_tag = ChartTagUtils.find_closest_chart_tag_to_position(player, spec.position)
  end

  if existing_chart_tag and existing_chart_tag.valid then
    -- Update existing chart tag instead of creating new one
    if spec.text then existing_chart_tag.text = spec.text end
    if spec.icon then existing_chart_tag.icon = spec.icon end
    if spec.last_user then existing_chart_tag.last_user = spec.last_user end
    return existing_chart_tag
  end

  -- Use protected call to catch any errors
  local success, result = pcall(function()
    return force.add_chart_tag(surface, spec)
  end)

  -- Check if creation was successful
  if not success then
    ErrorHandler.debug_log("Chart tag creation failed with error", {
      error = result,
      position = spec.position
    })
    return nil
  end

  -- Cast result to ensure proper typing after successful pcall
  ---@cast result LuaCustomChartTag
  -- Validate the created chart tag
  if not result or not result.valid then
    ErrorHandler.debug_log("Chart tag created but is invalid", {
      chart_tag_exists = result ~= nil,
      position = spec.position
    })
    return nil
  end

  -- Register the icon in icon_typing storage for O(1) lookup
  if spec.icon then
    local icon_typing = require("core.cache.icon_typing")
    icon_typing.format_icon_as_rich_text(spec.icon)
  end

  return result
end

return ChartTagUtils
