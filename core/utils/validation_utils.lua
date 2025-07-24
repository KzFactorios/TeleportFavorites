---@diagnostic disable: undefined-global

-- core/utils/validation_utils.lua
-- TeleportFavorites Factorio Mod
-- Consolidated validation utilities combining all validation functionality.
-- Provides a unified API for all validation operations throughout the mod.

local constants = require("constants")

---@class ValidationUtils
local ValidationUtils = {}


--- Standard player validation pattern used across event handlers
---@param player LuaPlayer|nil
---@return boolean is_valid
---@return string? error_message
function ValidationUtils.validate_player(player)
  return ValidationUtils.validate_factorio_object(player, "Player")
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

return ValidationUtils
