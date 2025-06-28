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

local constants = require("constants")
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
  return ValidationUtils.validate_factorio_object(player, "Player")
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

--- Validate tag object structure
---@param tag table|nil
---@return boolean is_valid
---@return string? error_message
function ValidationUtils.validate_tag_structure(tag)
  return ValidationUtils.validate_table_fields(tag, {"gps", "faved_by_players"}, "Tag")
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

--- Validate text length for chart tags and other user inputs
---@param text string|nil The text to validate
---@param max_length number? Maximum allowed length (defaults to CHART_TAG_TEXT_MAX_LENGTH)
---@param field_name string? Field name for error messages (defaults to "Text")
---@return boolean is_valid
---@return string? error_message
function ValidationUtils.validate_text_length(text, max_length, field_name)
  max_length = max_length or (constants.settings.CHART_TAG_TEXT_MAX_LENGTH --[[@as number]])
  field_name = field_name or "Text"
  
  if text == nil then
    text = ""
  end
  
  if type(text) ~= "string" then
    return false, field_name .. " must be a string"
  end
  
  if #text > max_length then
    return false, field_name .. " exceeds maximum length of " .. max_length .. " characters"
  end
  
  return true, nil
end

--- Generic validator for Factorio runtime objects (player, surface, force, chart_tag, etc.)
---@param obj table|nil
---@param type_name string
---@return boolean is_valid, string? error_message
function ValidationUtils.validate_factorio_object(obj, type_name)
  if not obj then return false, type_name .. " is nil" end
  if not obj.valid then return false, type_name .. " is not valid" end
  return true, nil
end

--- Validate required fields on a table
---@param tbl table|nil
---@param required_fields string[]
---@param type_name string
---@return boolean is_valid, string? error_message
function ValidationUtils.validate_table_fields(tbl, required_fields, type_name)
  if not tbl or type(tbl) ~= "table" then
    return false, type_name .. " must be a table"
  end
  for _, field in ipairs(required_fields) do
    if tbl[field] == nil then
      return false, type_name .. " missing required field: " .. field
    end
  end
  return true, nil
end

return ValidationUtils
