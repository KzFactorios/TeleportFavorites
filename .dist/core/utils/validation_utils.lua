---@diagnostic disable: undefined-global

local constants = require("constants")

---@class ValidationUtils
local ValidationUtils = {}


---@param player LuaPlayer|nil
---@return boolean is_valid
---@return string? error_message
function ValidationUtils.validate_player(player)
  return ValidationUtils.validate_factorio_object(player, "Player")
end

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

---@param text string|nil The text to validate
---@param max_length number? Maximum allowed length (defaults to CHART_TAG_TEXT_MAX_LENGTH)
---@param field_name string? Field name for error messages (defaults to "Text")
---@return boolean is_valid
---@return string? error_message
function ValidationUtils.validate_text_length(text, max_length, field_name)
  max_length = max_length or (constants.settings.CHART_TAG_TEXT_MAX_LENGTH )
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

---@param obj table|nil
---@param type_name string
---@return boolean is_valid, string? error_message
function ValidationUtils.validate_factorio_object(obj, type_name)
  if not obj then return false, type_name .. " is nil" end
  if not obj.valid then return false, type_name .. " is not valid" end
  return true, nil
end

return ValidationUtils
