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
local basic_helpers = require("core.utils.basic_helpers")
local ValidationHelpers = require("core.utils.validation_helpers")

---@class GPSChartHelpers
local GPSChartHelpers = {}

-- Local function to check if a position can be tagged using consolidated validation
local function position_can_be_tagged(player, map_position)
  -- Use consolidated validation helper for player check
  local player_valid, player_error = ValidationHelpers.validate_player_for_position_ops(player)
  if not player_valid then return false end
  
  -- Use consolidated validation helper for position check
  local pos_valid, pos_error = ValidationHelpers.validate_position_structure(map_position)
  if not pos_valid then return false end

  local chunk = { x = math.floor(map_position.x / 32), y = math.floor(map_position.y / 32) }
  if not player.force.is_chunk_charted(player.surface, chunk) then
    if player and player.valid then
      Helpers.player_print(player, "[TeleportFavorites] You are trying to create a tag in uncharted territory: " ..
        GPSCore.gps_from_map_position(map_position, player.surface.index))
    end    
    return false
  end

  if not Helpers.is_walkable_position(player.surface, map_position) then
    if player and player.valid then
      Helpers.player_print(player, "[TeleportFavorites] You cannot tag non-walkable locations: " ..
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
  
  -- Create the chart tag first using our safe wrapper
  local chart_tag = GPSChartHelpers.safe_add_chart_tag(player.force, player.surface, chart_tag_spec)

  -- Then validate using our position checker
  -- Note: We validate the created chart tag because position_can_be_tagged may not
  -- catch all Factorio API restrictions that only surface during actual creation
  if chart_tag and not position_can_be_tagged(player, chart_tag.position) then
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
  local new_position = { x = x, y = y }  -- Create new chart tag at aligned position using centralized builder
  local ChartTagSpecBuilder = require("core.utils.chart_tag_spec_builder")
  local chart_tag_spec = ChartTagSpecBuilder.build(new_position, chart_tag, player)
  
  -- Use our safe wrapper to create the chart tag
  local new_chart_tag = GPSChartHelpers.safe_add_chart_tag(player.force, player.surface, chart_tag_spec)

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

--- Safe wrapper for add_chart_tag to ensure consistent calling pattern
--- This prevents errors related to incorrect argument counts
---@param force LuaForce The force that will own the chart tag
---@param surface LuaSurface The surface where the tag will be placed
---@param spec table Chart tag specification table (position, text, etc.)
---@return LuaCustomChartTag|nil chart_tag The created chart tag or nil if failed
function GPSChartHelpers.safe_add_chart_tag(force, surface, spec)
  if not force or not surface or not spec then
    ErrorHandler.debug_log("Invalid arguments to safe_add_chart_tag", {
      has_force = force ~= nil,
      has_surface = surface ~= nil,
      has_spec = spec ~= nil
    })
    return nil
  end
  -- Use protected call to catch any errors
  local success, result = pcall(function()
    -- Create local variables to ensure clean argument passing
    local chart_tag
    do
      local temp_force = force
      -- use dot to access the correct call. Colon access wil fail
      chart_tag = temp_force.add_chart_tag(surface, spec)
    end
    return chart_tag
  end)

  if not success or not result or not result.valid then
    ErrorHandler.debug_log("Chart tag creation failed in wrapper", {
      success = success,
      error = not success and result or "Tag invalid after creation"
    })
    return nil
  end

  if not result or not result.valid or not position_can_be_tagged(result) then
    ErrorHandler.debug_log("Chart tag creation failed in wrapper", {
      success = success,
      error = not success and result or "Tag invalid after creation"
    })
    return nil
  end

  return result
end

return GPSChartHelpers
