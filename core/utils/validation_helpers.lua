---@diagnostic disable
--[[
validation_helpers.lua
TeleportFavorites Factorio Mod
-----------------------------
Consolidated validation utility patterns and helper functions.

This module centralizes common validation patterns to reduce code duplication
and provide consistent validation logic across the mod.

Features:
- Player validation patterns
- GPS string validation  
- Position validation utilities
- Chart tag validation helpers
- Common input validation patterns

Usage:
- Import this module to access standardized validation functions
- All functions follow consistent return patterns: (boolean success, string? error_message)
- Use these helpers instead of duplicating validation logic
--]]

local ErrorHandler = require("core.utils.error_handler")
local GPSCore = require("core.utils.gps_core")
local basic_helpers = require("core.utils.basic_helpers")

---@class ValidationHelpers
local ValidationHelpers = {}

-- ===========================================
-- PLAYER VALIDATION PATTERNS
-- ===========================================

--- Standard player validation pattern used across event handlers
--- Checks both player existence and validity
---@param player LuaPlayer|nil
---@return boolean is_valid
---@return string? error_message
function ValidationHelpers.validate_player(player)
  if not player or not player.valid then
    return false, "Invalid player reference"
  end
  return true, nil
end

--- Extended player validation including force and surface checks
---@param player LuaPlayer|nil
---@return boolean is_valid  
---@return string? error_message
function ValidationHelpers.validate_player_extended(player)
  if not player or not player.valid then
    return false, "Invalid player reference"
  end
  
  if not (player.force and player.surface) then
    return false, "Player missing force or surface"
  end
  
  return true, nil
end

--- Validate player for position operations (includes chart access)
---@param player LuaPlayer|nil
---@return boolean is_valid
---@return string? error_message
function ValidationHelpers.validate_player_for_position_ops(player)
  if not player or not player.valid then
    return false, "Invalid player reference"
  end
  
  if not (player.force and player.surface and player.force.is_chunk_charted) then
    return false, "Player missing required capabilities for position operations"
  end
  
  return true, nil
end

-- ===========================================
-- GPS VALIDATION PATTERNS
-- ===========================================

--- Validate GPS string format and content
---@param gps string|nil
---@return boolean is_valid
---@return string? error_message
function ValidationHelpers.validate_gps_string(gps)
  if not gps or type(gps) ~= "string" then
    return false, "GPS must be a string"
  end
  
  if basic_helpers.trim(gps) == "" then
    return false, "GPS string cannot be empty"
  end
  
  local parsed = GPSCore.parse_gps_string(gps)
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
function ValidationHelpers.validate_and_parse_gps(gps)
  local valid, error_msg = ValidationHelpers.validate_gps_string(gps)
  if not valid then
    return false, nil, error_msg
  end
  
  local position = GPSCore.map_position_from_gps(gps)
  if not position then
    return false, nil, "Failed to extract position from GPS"
  end
  
  return true, position, nil
end

-- ===========================================
-- POSITION VALIDATION PATTERNS
-- ===========================================

--- Validate basic position structure
---@param position MapPosition|nil
---@return boolean is_valid
---@return string? error_message
function ValidationHelpers.validate_position_structure(position)
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
---@param max_distance number? Maximum distance from origin (default: 100000)
---@return boolean is_valid
---@return string? error_message
function ValidationHelpers.validate_position_range(position, max_distance)
  local valid, error_msg = ValidationHelpers.validate_position_structure(position)
  if not valid then
    return false, error_msg
  end
  
  max_distance = max_distance or 100000
  local distance = math.sqrt(position.x * position.x + position.y * position.y)
  
  if distance > max_distance then
    return false, "Position too far from origin"
  end
  
  return true, nil
end

-- ===========================================
-- CHART TAG VALIDATION PATTERNS  
-- ===========================================

--- Validate chart tag object
---@param chart_tag LuaCustomChartTag|nil
---@return boolean is_valid
---@return string? error_message
function ValidationHelpers.validate_chart_tag(chart_tag)
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
function ValidationHelpers.validate_chart_tag_with_position(chart_tag)
  local valid, error_msg = ValidationHelpers.validate_chart_tag(chart_tag)
  if not valid then
    return false, error_msg
  end
  
  if not chart_tag.position then
    return false, "Chart tag missing position"
  end
  
  local pos_valid, pos_error = ValidationHelpers.validate_position_structure(chart_tag.position)
  if not pos_valid then
    return false, "Chart tag has invalid position: " .. (pos_error or "unknown error")
  end
  
  return true, nil
end

-- ===========================================
-- TAG VALIDATION PATTERNS
-- ===========================================

--- Validate tag object structure
---@param tag table|nil
---@return boolean is_valid
---@return string? error_message
function ValidationHelpers.validate_tag_structure(tag)
  if not tag or type(tag) ~= "table" then
    return false, "Tag must be a table"
  end
  
  if not tag.gps or type(tag.gps) ~= "string" then
    return false, "Tag must have a valid GPS string"
  end
  
  return true, nil
end

--- Validate tag using GPS patterns
---@param tag table|nil
---@return boolean is_valid
---@return string? error_message
function ValidationHelpers.validate_tag_with_gps(tag)
  local valid, error_msg = ValidationHelpers.validate_tag_structure(tag)
  if not valid then
    return false, error_msg
  end
  
  local gps_valid, gps_error = ValidationHelpers.validate_gps_string(tag.gps)
  if not gps_valid then
    return false, "Tag has invalid GPS: " .. (gps_error or "unknown error")
  end
  
  return true, nil
end

--- Validate position for tagging operations (includes chunk charted check)
---@param player LuaPlayer
---@param position MapPosition
---@return boolean is_valid
---@return string? error_message
function ValidationHelpers.validate_position_for_tagging(player, position)
  -- Basic validation first
  local player_valid, player_error = ValidationHelpers.validate_player_for_position_ops(player)
  if not player_valid then
    return false, player_error
  end
  
  local pos_valid, pos_error = ValidationHelpers.validate_position_structure(position)
  if not pos_valid then
    return false, pos_error
  end
  
  -- Check if chunk is charted
  local chunk = { x = math.floor(position.x / 32), y = math.floor(position.y / 32) }
  if not player.force.is_chunk_charted(player.surface, chunk) then
    return false, "Position is not in charted territory"
  end
  
  return true, nil
end

-- ===========================================
-- COMBINED VALIDATION PATTERNS
-- ===========================================

--- Comprehensive validation for position operations
--- Validates player, GPS, and extracts position in one call
---@param player LuaPlayer|nil
---@param gps string|nil
---@return boolean is_valid
---@return MapPosition? position
---@return string? error_message
function ValidationHelpers.validate_position_operation(player, gps)
  -- Validate player first
  local player_valid, player_error = ValidationHelpers.validate_player_for_position_ops(player)
  if not player_valid then
    return false, nil, player_error
  end
  
  -- Validate and parse GPS
  local gps_valid, position, gps_error = ValidationHelpers.validate_and_parse_gps(gps)
  if not gps_valid then
    return false, nil, gps_error
  end
  
  -- Validate position range
  local range_valid, range_error = ValidationHelpers.validate_position_range(position)
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
function ValidationHelpers.validate_sync_inputs(player, tag, new_gps)
  local issues = {}
  
  local player_valid, player_error = ValidationHelpers.validate_player(player)
  if not player_valid then
    table.insert(issues, player_error)
  end
  
  if tag then
    local tag_valid, tag_error = ValidationHelpers.validate_tag_structure(tag)
    if not tag_valid then
      table.insert(issues, tag_error)
    end
  end
  
  if new_gps then
    local gps_valid, gps_error = ValidationHelpers.validate_gps_string(new_gps)
    if not gps_valid then
      table.insert(issues, "New GPS invalid: " .. (gps_error or "unknown error"))
    end
  end
  
  return #issues == 0, issues
end

-- ===========================================
-- UTILITY FUNCTIONS
-- ===========================================

--- Create standardized validation result with error logging
---@param is_valid boolean
---@param error_message string?
---@param context table? Additional context for logging
---@return boolean is_valid
---@return string? error_message
function ValidationHelpers.create_validation_result(is_valid, error_message, context)
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
function ValidationHelpers.validate_all(validations)
  for _, validation in ipairs(validations) do
    local func = validation[1]
    local args = {unpack(validation, 2)}
    
    local valid, error_msg = func(unpack(args))
    if not valid then
      return false, error_msg
    end
  end
  
  return true, nil
end

return ValidationHelpers
