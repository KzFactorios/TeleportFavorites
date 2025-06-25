---@diagnostic disable: undefined-global
--[[
GUI Validation Utilities for TeleportFavorites
=============================================
Module: core/utils/gui_validation.lua

Provides validation and safety utilities for GUI elements and operations.

Functions:
- validate_gui_element() - Check if GUI element exists and is valid
- set_element_visibility() - Safely set element visibility
- set_element_text() - Safely set element text/caption
- apply_style_properties() - Apply style properties with error handling
- safe_destroy_frame() - Safe GUI frame destruction
]]

local ErrorHandler = require("core.utils.error_handler")

---@class GuiValidation
local GuiValidation = {}

--- Validate GUI element exists and is valid
---@param element LuaGuiElement? Element to validate
---@return boolean is_valid True if element is valid
function GuiValidation.validate_gui_element(element)
  return element ~= nil and element.valid == true
end

--- Set GUI element visibility with validation
---@param element LuaGuiElement? Element to modify
---@param visible boolean Visibility state
---@return boolean success True if successfully set
function GuiValidation.set_element_visibility(element, visible)
  if not GuiValidation.validate_gui_element(element) then return false end
  ---@cast element -nil
  
  element.visible = visible
  return true
end

--- Set GUI element text with validation
---@param element LuaGuiElement? Element to modify
---@param text string Text to set
---@return boolean success True if successfully set
function GuiValidation.set_element_text(element, text)
  if not GuiValidation.validate_gui_element(element) then return false end
  ---@cast element -nil
  
  if element.type == "label" or element.type == "button" then
    ---@diagnostic disable-next-line: assign-type-mismatch
    element.caption = text
  elseif element.type == "textfield" or element.type == "text-box" then
    element.text = text
  else
    return false
  end
  
  return true
end

--- Apply style properties to element with validation
---@param element LuaGuiElement? Element to style
---@param style_props table Style properties to apply
---@return boolean success True if successfully applied
function GuiValidation.apply_style_properties(element, style_props)
  if not GuiValidation.validate_gui_element(element) or type(style_props) ~= "table" then
    return false
  end
  ---@cast element -nil
  
  local success, error_msg = pcall(function()
    for prop, value in pairs(style_props) do
      element.style[prop] = value
    end
  end)
  
  if not success then
    ErrorHandler.debug_log("Failed to apply style properties", {
      element_name = element.name or "<no name>",
      element_type = element.type or "<no type>",
      error = error_msg
    })
  end
  
  return success
end

--- Safe GUI frame destruction
---@param parent LuaGuiElement Parent element containing the frame
---@param frame_name string Name of the frame to destroy
function GuiValidation.safe_destroy_frame(parent, frame_name)
  if not parent or not frame_name then return end
  
  if parent[frame_name] and parent[frame_name].valid and type(parent[frame_name].destroy) == "function" then
    parent[frame_name].destroy()
  end
end

--- Set button state and apply style overrides
---@param element LuaGuiElement Button element to modify
---@param enabled boolean? Whether the button should be enabled (default: true)
---@param style_overrides table? Style properties to override
function GuiValidation.set_button_state(element, enabled, style_overrides)
  if not element or not element.valid then
    ErrorHandler.debug_log("set_button_state: element is nil or invalid")
    return
  end
  
  if not (element.type == "button" or element.type == "sprite-button" or 
          element.type == "textfield" or element.type == "text-box" or 
          element.type == "choose-elem-button") then
    ErrorHandler.debug_log("set_button_state: Unexpected element type", {
      type = element.type,
      name = element.name
    })
    return
  end
  
  element.enabled = enabled ~= false
  
  if (element.type == "button" or element.type == "sprite-button" or element.type == "choose-elem-button") and 
     style_overrides and type(style_overrides) == "table" then
    for k, v in pairs(style_overrides) do
      element.style[k] = v
    end
  end
end

-- ========================================
-- ERROR HANDLING AND USER FEEDBACK
-- ========================================

--- Centralized error handling and user feedback for GUI operations
---@param player LuaPlayer|nil Player to notify (optional)
---@param message string|table Error or info message to show
---@param level string? Error level: 'error', 'info', or 'warn' (default: 'error')
---@param log_to_console boolean? Whether to log to console (default: true)
function GuiValidation.handle_error(player, message, level, log_to_console)
  local LocaleUtils = require("core.utils.locale_utils")
  local ErrorHandler = require("core.utils.error_handler")
  
  level = level or 'error'
  log_to_console = log_to_console ~= false
  local msg = (type(message) == 'table' and table.concat(message, ' ')) or tostring(message)
  
  local function safe_player_print(player, message)
    if player and player.valid and type(player.print) == "function" then
      pcall(function() player.print(message) end)
    end
  end
  
  -- Notify player if available
  if player and player.valid then
    if level == 'error' then
      local prefix = LocaleUtils.get_error_string(player, "error_prefix")
      safe_player_print(player, { '', '[color=red]', prefix, ' ', msg, '[/color]' })
    elseif level == 'warn' then
      local prefix = LocaleUtils.get_error_string(player, "warn_prefix")
      safe_player_print(player, { '', '[color=orange]', prefix, ' ', msg, '[/color]' })
    else
      local prefix = LocaleUtils.get_error_string(player, "info_prefix")
      safe_player_print(player, { '', '[color=white]', prefix, ' ', msg, '[/color]' })
    end
  end
  
  if log_to_console then
    local log_msg = '[TeleportFavorites][' .. level:upper() .. '] ' .. msg
    ErrorHandler.debug_log(log_msg)
  end
end

--- Show error label in a GUI frame
---@param parent LuaGuiElement Parent GUI element
---@param message string Error message to display
function GuiValidation.show_error_label(parent, message)
  local LocaleUtils = require("core.utils.locale_utils")
  
  if not parent or not parent.valid then return end
  local error_label = parent["tf_error_label"]
  if not error_label then
    local GuiBase = require("gui.gui_base")
    error_label = GuiBase.create_label(parent, "tf_error_label", "", "tf_error_label")
  end
  error_label.caption = message and LocaleUtils.get_string(nil, message) or ""
  error_label.visible = true
end

--- Clear error label from a GUI frame  
---@param parent LuaGuiElement Parent GUI element
function GuiValidation.clear_error_label(parent)
  if not parent or not parent.valid then return end
  local error_label = parent["tf_error_label"]
  if error_label and error_label.valid then
    error_label.visible = false
    error_label.caption = ""
  end
end

-- ========================================
-- ELEMENT FINDING AND VALIDATION
-- ========================================

--- Get the top-level GUI frame that contains an element
---@param element LuaGuiElement Element to search from
---@return LuaGuiElement|nil Top-level frame or nil if not found
function GuiValidation.get_gui_frame_by_element(element)
  if not element or not element.valid then return nil end
  
  local current = element
  local iterations = 0
  local max_iterations = 20
  
  while current and current.valid and iterations < max_iterations do
    iterations = iterations + 1
    
    if current.type == "frame" then
      local name = current.name or ""
      if name:find("tag_editor_outer_frame") or 
         name:find("data_viewer_outer_frame") or
         name:find("fave_bar_outer_frame") then
        return current
      end
    end
    
    current = current.parent
  end
  
  return nil
end

--- Recursively find child element by name
---@param parent LuaGuiElement Parent element to search in
---@param child_name string Name of child to find
---@return LuaGuiElement|nil Found child element or nil
function GuiValidation.find_child_by_name(parent, child_name)
  if not parent or not parent.valid or not child_name then return nil end
  
  -- Direct child check
  local direct_child = parent[child_name]
  if direct_child and direct_child.valid then
    return direct_child
  end
  
  -- Recursive search with depth limit
  local function recursive_search(element, name, depth)
    if depth > 10 then return nil end
    
    for _, child in pairs(element.children) do
      if child.valid then
        if child.name == name then
          return child
        end
        
        local found = recursive_search(child, name, depth + 1)
        if found then return found end
      end
    end
    return nil
  end
  
  return recursive_search(parent, child_name, 0)
end

--- Validate sprite path exists and is usable
---@param sprite_path string|nil Sprite path to validate
---@return boolean is_valid Whether sprite is valid
---@return string? error_message Error message if invalid
function GuiValidation.validate_sprite(sprite_path)
  if not sprite_path or type(sprite_path) ~= "string" or sprite_path == "" then
    return false, "Sprite path is nil or empty"
  end
  
  -- Basic format validation
  if not sprite_path:match("^[%w_%-/%.]+$") then
    return false, "Sprite path contains invalid characters"
  end
  
  -- Check for common patterns
  local valid_prefixes = {
    "item/", "entity/", "technology/", "recipe/", 
    "fluid/", "tile/", "signal/", "utility/",
    "virtual-signal/", "equipment/", "achievement/"
  }
  
  local has_valid_prefix = false
  for _, prefix in ipairs(valid_prefixes) do
    if sprite_path:sub(1, #prefix) == prefix then
      has_valid_prefix = true
      break
    end
  end
  
  if not has_valid_prefix then
    return false, "Sprite path does not have a recognized prefix"
  end
  
  return true, nil
end

--- Get debug information about a sprite
---@param sprite_path string Sprite path to debug
---@return table Debug information about the sprite
function GuiValidation.debug_sprite_info(sprite_path)
  local info = {
    path = sprite_path,
    valid = false,
    error = nil,
    type = nil,
    name = nil
  }
  
  local is_valid, error_msg = GuiValidation.validate_sprite(sprite_path)
  info.valid = is_valid
  info.error = error_msg
  
  if sprite_path and type(sprite_path) == "string" then
    local slash_pos = sprite_path:find("/")
    if slash_pos then
      info.type = sprite_path:sub(1, slash_pos - 1)
      info.name = sprite_path:sub(slash_pos + 1)
    end
  end
  
  return info
end

return GuiValidation
