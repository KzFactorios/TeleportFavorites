---@diagnostic disable: undefined-global
--[[
core/utils/validation_utils.lua
TeleportFavorites Factorio Mod
-----------------------------
Consolidated validation utilities combining all validation functionality.

This module consolidates:
- validation_helpers.lua - Common validation patterns and helpers
- icon_validator.lua - Icon and signal validation
- Validation functions from other modules

Provides a unified API for all validation operations throughout the mod.
]]

local ErrorHandler = require("core.utils.error_handler")
local basic_helpers = require("core.utils.basic_helpers")
local GPSUtils = require("core.utils.gps_utils")

---@class ValidationUtils
local ValidationUtils = {}

-- ========================================
-- PLAYER VALIDATION PATTERNS
-- ========================================

--- Standard player validation pattern used across event handlers
---@param player LuaPlayer|nil
---@return boolean is_valid
---@return string? error_message
function ValidationUtils.validate_player(player)
  if not player then
    return false, "Player is nil"
  end
  
  if not player.valid then
    return false, "Player is not valid"
  end
  
  return true, nil
end

--- Extended player validation for position operations
---@param player LuaPlayer|nil
---@return boolean is_valid
---@return string? error_message
function ValidationUtils.validate_player_for_position_ops(player)
  local basic_valid, basic_error = ValidationUtils.validate_player(player)
  if not basic_valid then
    return false, basic_error
  end
  
  -- player is guaranteed to be valid at this point
  assert(player, "Player should not be nil after validation")
  
  if not player.force or not player.surface then
    return false, "Player missing force or surface"
  end
  
  if not player.surface.valid then
    return false, "Player surface is not valid"
  end
  
  return true, nil
end

--- Validate player for GUI operations
---@param player LuaPlayer|nil
---@return boolean is_valid
---@return string? error_message
function ValidationUtils.validate_player_for_gui(player)
  local basic_valid, basic_error = ValidationUtils.validate_player(player)
  if not basic_valid then
    return false, basic_error
  end
  
  -- player is guaranteed to be valid at this point
  assert(player, "Player should not be nil after validation")
  
  if not player.gui then
    return false, "Player GUI is not available"
  end
  
  return true, nil
end

-- ========================================
-- GPS VALIDATION PATTERNS
-- ========================================

--- Validate GPS string format and content
---@param gps string|nil
---@return boolean is_valid
---@return string? error_message
function ValidationUtils.validate_gps_string(gps)
  if not gps or type(gps) ~= "string" then
    return false, "GPS must be a string"
  end
  
  if basic_helpers.trim(gps) == "" then
    return false, "GPS string cannot be empty"
  end
    -- Use GPSUtils for actual parsing validation
  local parsed = GPSUtils.parse_gps_string(gps)
  if not parsed then
    return false, "Invalid GPS format"
  end
  
  return true, nil
end

--- Validate GPS and extract position information
---@param gps string|nil
---@return boolean is_valid
---@return MapPosition? position
---@return string? error_message
function ValidationUtils.validate_and_parse_gps(gps)
  local valid, error_msg = ValidationUtils.validate_gps_string(gps)
  if not valid then
    return false, nil, error_msg
  end
    -- gps is guaranteed to be a string at this point due to validation above
  local position = GPSUtils.map_position_from_gps(gps --[[@as string]])
  if not position then
    return false, nil, "Failed to extract position from GPS"
  end
  
  return true, position, nil
end

-- ========================================
-- POSITION VALIDATION PATTERNS
-- ========================================

--- Validate basic position structure
---@param position MapPosition|nil
---@return boolean is_valid
---@return string? error_message
function ValidationUtils.validate_position_structure(position)
  if not position or type(position) ~= "table" then
    return false, "Position must be a table"
  end
  
  if type(position.x) ~= "number" or type(position.y) ~= "number" then
    return false, "Position must have numeric x and y coordinates"
  end
  
  return true, nil
end

--- Validate that a position is within a reasonable range
---@param position MapPosition
---@param max_distance number? Maximum distance from origin (default: 2000000)
---@return boolean is_valid
---@return string? error_message
function ValidationUtils.validate_position_range(position, max_distance)
  -- Factorio's practical world limit
  max_distance = max_distance or 2000000
  
  if math.abs(position.x) > max_distance or math.abs(position.y) > max_distance then
    return false, "Position is outside reasonable world bounds"
  end
  
  return true, nil
end

--- Validate position for tagging operations (includes chunk charted check)
---@param player LuaPlayer
---@param position MapPosition
---@return boolean is_valid
---@return string? error_message
function ValidationUtils.validate_position_for_tagging(player, position)
  -- Basic validation first
  local player_valid, player_error = ValidationUtils.validate_player_for_position_ops(player)
  if not player_valid then
    return false, player_error
  end
  
  local pos_valid, pos_error = ValidationUtils.validate_position_structure(position)
  if not pos_valid then
    return false, pos_error
  end
  
  -- Check if chunk is charted
  local chunk = { x = math.floor(position.x / 32), y = math.floor(position.y / 32) }
  if not player.force:is_chunk_charted(player.surface, chunk) then
    return false, "Position is not in charted territory"
  end
  
  return true, nil
end

-- ========================================
-- CHART TAG VALIDATION PATTERNS
-- ========================================

--- Validate chart tag object
---@param chart_tag LuaCustomChartTag|nil
---@return boolean is_valid
---@return string? error_message
function ValidationUtils.validate_chart_tag(chart_tag)
  if not chart_tag then
    return false, "Chart tag is nil"
  end
  
  if not chart_tag.valid then
    return false, "Chart tag is not valid"
  end
  
  return true, nil
end

--- Validate chart tag with position check
---@param chart_tag LuaCustomChartTag|nil
---@return boolean is_valid
---@return string? error_message
function ValidationUtils.validate_chart_tag_with_position(chart_tag)
  local valid, error_msg = ValidationUtils.validate_chart_tag(chart_tag)
  if not valid then
    return false, error_msg
  end
  
  -- chart_tag is guaranteed to be valid at this point
  assert(chart_tag, "Chart tag should not be nil after validation")
  
  if not chart_tag.position then
    return false, "Chart tag missing position"
  end
  
  local pos_valid, pos_error = ValidationUtils.validate_position_structure(chart_tag.position)
  if not pos_valid then
    return false, "Chart tag has invalid position: " .. (pos_error or "unknown error")
  end
  
  return true, nil
end

-- ========================================
-- TAG VALIDATION PATTERNS
-- ========================================

--- Validate tag object structure
---@param tag table|nil
---@return boolean is_valid
---@return string? error_message
function ValidationUtils.validate_tag_structure(tag)
  if not tag or type(tag) ~= "table" then
    return false, "Tag must be a table"
  end
  
  if not tag.gps or type(tag.gps) ~= "string" then
    return false, "Tag must have a valid GPS string"
  end
  
  if not tag.faved_by_players or type(tag.faved_by_players) ~= "table" then
    return false, "Tag must have a faved_by_players array"
  end
  
  return true, nil
end

--- Validate tag using GPS patterns
---@param tag table|nil
---@return boolean is_valid
---@return string? error_message
function ValidationUtils.validate_tag_with_gps(tag)
  local valid, error_msg = ValidationUtils.validate_tag_structure(tag)
  if not valid then
    return false, error_msg
  end
  
  -- tag is guaranteed to be valid at this point
  assert(tag, "Tag should not be nil after validation")
  
  local gps_valid, gps_error = ValidationUtils.validate_gps_string(tag.gps)
  if not gps_valid then
    return false, "Tag has invalid GPS: " .. (gps_error or "unknown error")
  end
  
  return true, nil
end

-- ========================================
-- ICON AND SIGNAL VALIDATION
-- ========================================

--- Validate signal/icon structure
---@param signal table|nil
---@return boolean is_valid
---@return string? error_message
function ValidationUtils.validate_signal_structure(signal)
  if not signal or type(signal) ~= "table" then
    return false, "Signal must be a table"
  end
  
  if not signal.type or type(signal.type) ~= "string" then
    return false, "Signal must have a valid type string"
  end
  
  if not signal.name or type(signal.name) ~= "string" then
    return false, "Signal must have a valid name string"
  end
  
  return true, nil
end

--- Validate icon for chart tags
---@param icon table|nil
---@return boolean is_valid
---@return string? error_message
function ValidationUtils.validate_chart_tag_icon(icon)
  if not icon then
    -- Icons are optional
    return true, nil
  end
  
  return ValidationUtils.validate_signal_structure(icon)
end

--- Validate icon exists in game prototypes
---@param icon table Icon to validate
---@return boolean exists
---@return string? error_message
function ValidationUtils.validate_icon_exists(icon)
  local valid, error_msg = ValidationUtils.validate_signal_structure(icon)
  if not valid then
    return false, error_msg
  end
  
  -- For now, just validate the structure. Runtime prototype checking can be added later.
  -- The game's chart tag creation will fail gracefully if the icon doesn't exist.
  return true, nil
end

--- Validate if an icon is valid for chart tag creation
--- This handles various icon formats from choose-elem-button and string formats
---@param icon any Icon data from choose-elem-button or other sources
---@return boolean is_valid True if icon can be used for chart tags
function ValidationUtils.has_valid_icon(icon)
  if not icon or icon == "" then 
    return false 
  end
  
  if type(icon) == "string" then 
    return true 
  end
  
  if type(icon) == "table" then 
    return (icon.name ~= nil) or (icon.type ~= nil)
  end
  
  return false
end

-- ========================================
-- SURFACE AND FORCE VALIDATION
-- ========================================

--- Validate surface object
---@param surface LuaSurface|nil
---@return boolean is_valid
---@return string? error_message
function ValidationUtils.validate_surface(surface)
  if not surface then
    return false, "Surface is nil"
  end
  
  if not surface.valid then
    return false, "Surface is not valid"
  end
  
  return true, nil
end

--- Validate force object
---@param force LuaForce|nil
---@return boolean is_valid
---@return string? error_message
function ValidationUtils.validate_force(force)
  if not force then
    return false, "Force is nil"
  end
  
  if not force.valid then
    return false, "Force is not valid"
  end
  
  return true, nil
end

-- ========================================
-- COMBINED VALIDATION PATTERNS
-- ========================================

--- Comprehensive validation for position operations
---@param player LuaPlayer|nil
---@param gps string|nil
---@return boolean is_valid
---@return MapPosition? position
---@return string? error_message
function ValidationUtils.validate_position_operation(player, gps)
  -- Validate player first
  local player_valid, player_error = ValidationUtils.validate_player_for_position_ops(player)
  if not player_valid then
    return false, nil, player_error
  end
  
  -- Validate and parse GPS
  local gps_valid, position, gps_error = ValidationUtils.validate_and_parse_gps(gps)
  if not gps_valid then
    return false, nil, gps_error
  end
  
  -- position is guaranteed to be valid at this point due to validation above
  local range_valid, range_error = ValidationUtils.validate_position_range(position --[[@as MapPosition]])
  if not range_valid then
    return false, nil, range_error
  end
  
  return true, position, nil
end

--- Validate tag synchronization inputs
---@param player LuaPlayer|nil
---@param tag table|nil
---@param new_gps string|nil
---@return boolean is_valid
---@return string[] issues List of validation issues
function ValidationUtils.validate_sync_inputs(player, tag, new_gps)
  local issues = {}
  
  local player_valid, player_error = ValidationUtils.validate_player(player)
  if not player_valid then
    table.insert(issues, player_error)
  end
  
  if tag then
    local tag_valid, tag_error = ValidationUtils.validate_tag_structure(tag)
    if not tag_valid then
      table.insert(issues, tag_error)
    end
  end
  
  if new_gps then
    local gps_valid, gps_error = ValidationUtils.validate_gps_string(new_gps)
    if not gps_valid then
      table.insert(issues, "New GPS invalid: " .. (gps_error or "unknown error"))
    end
  end
  
  return #issues == 0, issues
end

-- ========================================
-- GUI VALIDATION PATTERNS
-- ========================================

--- Validate GUI element exists and is valid
---@param element LuaGuiElement|nil
---@return boolean is_valid
---@return string? error_message
function ValidationUtils.validate_gui_element(element)
  if not element then
    return false, "GUI element is nil"
  end
  
  if not element.valid then
    return false, "GUI element is not valid"
  end
  
  return true, nil
end

--- Validate GUI parent element for adding children
---@param parent LuaGuiElement|nil
---@return boolean is_valid
---@return string? error_message
function ValidationUtils.validate_gui_parent(parent)
  local valid, error_msg = ValidationUtils.validate_gui_element(parent)
  if not valid then
    return false, error_msg
  end
  
  -- parent is guaranteed to be valid at this point
  assert(parent, "Parent should not be nil after validation")
  
  -- Check if parent can contain children
  if parent.type == "checkbox" or parent.type == "radiobutton" or 
     parent.type == "textfield" or parent.type == "text-box" then
    return false, "GUI element cannot contain children"
  end
  
  return true, nil
end

-- ========================================
-- UTILITY FUNCTIONS
-- ========================================

--- Create standardized validation result with error logging
---@param is_valid boolean
---@param error_message string?
---@param context table? Additional context for logging
---@return boolean is_valid
---@return string? error_message
function ValidationUtils.create_validation_result(is_valid, error_message, context)
  if not is_valid and error_message then
    ErrorHandler.debug_log("Validation failed", {
      error = error_message,
      context = context
    })
  end
  
  return is_valid, error_message
end

--- Validate multiple inputs with early exit on first failure
---@param validations table[] Array of {func, args...} validation calls
---@return boolean all_valid
---@return string? first_error
function ValidationUtils.validate_multiple(validations)
  for _, validation in ipairs(validations) do
    local func = validation[1]
    local args = { table.unpack(validation, 2) }
    
    local valid, error_msg = func(table.unpack(args))
    if not valid then
      return false, error_msg
    end
  end
  
  return true, nil
end

--- Validate input is not nil or empty
---@param value any
---@param field_name string
---@return boolean is_valid
---@return string? error_message
function ValidationUtils.validate_not_empty(value, field_name)
  if value == nil then
    return false, field_name .. " cannot be nil"
  end
  
  if type(value) == "string" and basic_helpers.trim(value) == "" then
    return false, field_name .. " cannot be empty"
  end
  
  if type(value) == "table" and next(value) == nil then
    return false, field_name .. " cannot be an empty table"
  end
  
  return true, nil
end

--- Validate numerical range
---@param value number
---@param min_val number
---@param max_val number
---@param field_name string
---@return boolean is_valid
---@return string? error_message
function ValidationUtils.validate_range(value, min_val, max_val, field_name)
  if type(value) ~= "number" then
    return false, field_name .. " must be a number"
  end
  
  if value < min_val or value > max_val then
    return false, field_name .. " must be between " .. min_val .. " and " .. max_val
  end
  
  return true, nil
end

return ValidationUtils
