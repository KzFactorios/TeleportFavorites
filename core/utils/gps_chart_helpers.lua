---@diagnostic disable
--[[
core/utils/gps_chart_helpers.lua
TeleportFavorites Factorio Mod
-----------------------------
Chart tag creation, validation, and management utilities.

- Create-then-validate pattern for chart tags
- Position validation for taggable locations
- Chart tag alignment and repositioning
]]

local Helpers = require("core.utils.helpers_suite")
local ErrorHandler = require("core.utils.error_handler")
local GPSCore = require("core.utils.gps_core")

---@class GPSChartHelpers
local GPSChartHelpers = {}

-- Local function to check if a position can be tagged (moved from position_helpers to break circular dependency)
local function position_can_be_tagged(player, map_position)
  if not (player and player.force and player.surface and player.force.is_chunk_charted) then return false end
  if not map_position then return false end

  local chunk = { x = math.floor(map_position.x / 32), y = math.floor(map_position.y / 32) }
  if not player.force.is_chunk_charted(player.surface, chunk) then
    if player and player.valid then
      player:print("[TeleportFavorites] You are trying to create a tag in uncharted territory: " ..
        GPSCore.gps_from_map_position(map_position, player.surface.index))
    end
    return false
  end
  
  if Helpers.is_water_tile(player.surface, map_position) or Helpers.is_space_tile(player.surface, map_position) then
    if player and player.valid then
      player:print("[TeleportFavorites] You cannot tag water or space in this interface: " ..
        GPSCore.gps_from_map_position(map_position, player.surface.index))
    end
    return false
  end

  return true
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

-- Export public functions
GPSChartHelpers.position_can_be_tagged = position_can_be_tagged
GPSChartHelpers.create_and_validate_chart_tag = create_and_validate_chart_tag

return GPSChartHelpers
