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

--- Align a chart tag's position to whole number coordinates if needed
--- This is a simplified version that doesn't require the Tag module
---@param player LuaPlayer
---@param chart_tag LuaCustomChartTag
---@return LuaCustomChartTag|nil
local function align_chart_tag_position(player, chart_tag)
  if not player or not player.valid or not chart_tag or not chart_tag.valid then
    return nil
  end
  
  local basic_helpers = require("core.utils.basic_helpers")
  local GPSCore = require("core.utils.gps_core")
  
  -- Check if alignment is needed
  if basic_helpers.is_whole_number(chart_tag.position.x) and basic_helpers.is_whole_number(chart_tag.position.y) then
    return chart_tag -- No alignment needed
  end
  
  ErrorHandler.debug_log("Aligning chart tag to whole number coordinates", {
    current_position = chart_tag.position
  })
  
  -- Normalize coordinates to whole numbers
  local x = basic_helpers.normalize_index(chart_tag.position.x)
  local y = basic_helpers.normalize_index(chart_tag.position.y)
  
  if not x or not y then
    ErrorHandler.debug_log("Failed to normalize chart tag coordinates")
    return chart_tag -- Return original if normalization fails
  end
  
  local new_position = { x = x, y = y }
  
  -- Create new chart tag at aligned position
  local chart_tag_spec = {
    position = new_position,
    icon = chart_tag.icon or {},
    text = chart_tag.text or "",
    last_user = chart_tag.last_user or player.name
  }
  
  local new_chart_tag = player.force:add_chart_tag(player.surface, chart_tag_spec)
  if not new_chart_tag or not new_chart_tag.valid then
    ErrorHandler.debug_log("Failed to create aligned chart tag")
    return chart_tag -- Return original if creation fails
  end
  
  -- Destroy the old chart tag
  if chart_tag.valid then
    chart_tag.destroy()
  end
  
  ErrorHandler.debug_log("Successfully aligned chart tag position", {
    old_position = chart_tag.position,
    new_position = new_position
  })
  
  return new_chart_tag
end

-- Export public functions
GPSChartHelpers.position_can_be_tagged = position_can_be_tagged
GPSChartHelpers.create_and_validate_chart_tag = create_and_validate_chart_tag
GPSChartHelpers.align_chart_tag_position = align_chart_tag_position

return GPSChartHelpers
