---@diagnostic disable: undefined-global
--[[
core/utils/gui_utils.lua
TeleportFavorites Factorio Mod
-----------------------------
Consolidated GUI utilities combining all GUI-related functionality.

This module consolidates:
- gui_helpers.lua - GUI element creation, error handling, and state management
- style_helpers.lua - Dynamic style creation and management  
- rich_text_formatter.lua - Rich text formatting for notifications and displays
- sprite_debugger.lua - Sprite validation and debugging utilities

Provides a unified API for all GUI operations throughout the mod.
]]

local ErrorHandler = require("core.utils.error_handler")
local basic_helpers = require("core.utils.basic_helpers")
local GuiBase = require("gui.gui_base")

---@class GuiUtils
local GuiUtils = {}

-- ========================================
-- GUI ELEMENT CREATION AND MANAGEMENT
-- ========================================

--- Centralized error handling and user feedback for GUI operations
---@param player LuaPlayer|nil Player to notify (optional)
---@param message string|table Error or info message to show
---@param level string? Error level: 'error', 'info', or 'warn' (default: 'error')
---@param log_to_console boolean? Whether to log to console (default: true)
function GuiUtils.handle_error(player, message, level, log_to_console)
  level = level or 'error'
  log_to_console = log_to_console ~= false
  local msg = (type(message) == 'table' and table.concat(message, ' ')) or tostring(message)
  
  -- Notify player if available
  if player and player.valid and type(player.print) == 'function' then
    if level == 'error' then
      player.print({ '', '[color=red][ERROR] ', msg, '[/color]' }, { r = 1, g = 0.2, b = 0.2 })
    elseif level == 'warn' then
      player.print({ '', '[color=orange][WARN] ', msg, '[/color]' }, { r = 1, g = 0.5, b = 0 })
    else
      player.print({ '', '[color=white][INFO] ', msg, '[/color]' }, { r = 1, g = 1, b = 1 })
    end
  end
  
  if log_to_console then
    local log_msg = '[TeleportFavorites][' .. level:upper() .. '] ' .. msg
    ErrorHandler.debug_log(log_msg)
  end
end

--- Safe GUI frame destruction
---@param parent LuaGuiElement Parent element containing the frame
---@param frame_name string Name of the frame to destroy
function GuiUtils.safe_destroy_frame(parent, frame_name)
  if not parent or not frame_name then return end
  
  if parent[frame_name] and parent[frame_name].valid and type(parent[frame_name].destroy) == "function" then
    parent[frame_name]:destroy()
  end
end

--- Show error label with styled message
---@param parent LuaGuiElement Parent element for the error label
---@param message string Error message to display
---@return LuaGuiElement? error_label Created or updated error label
function GuiUtils.show_error_label(parent, message)
  if not parent or not message then return end
  
  local label = parent.error_row_error_message or GuiBase.create_label(parent, "error_row_error_message", "", "bold_label")
  if label then
    label.caption = message or ""
    label.style.font_color = { r = 1, g = 0.2, b = 0.2 }
    label.visible = (message and message ~= "")
  end
  return label
end

--- Clear error label
---@param parent LuaGuiElement Parent element containing the error label
function GuiUtils.clear_error_label(parent)
  if parent and parent.error_row_error_message then
    parent.error_row_error_message.caption = ""
    parent.error_row_error_message.visible = false
  end
end

--- Set button state and apply style overrides
---@param element LuaGuiElement Button element to modify
---@param enabled boolean? Whether the button should be enabled (default: true)
---@param style_overrides table? Style properties to override
function GuiUtils.set_button_state(element, enabled, style_overrides)
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

--- Build tooltip for favorites
---@param fav table Favorite object
---@param opts table? Options including gps, text, max_len
---@return table tooltip Localized tooltip table
function GuiUtils.build_favorite_tooltip(fav, opts)
  opts = opts or {}
  local gps_str = fav and fav.gps or opts.gps or "?"
  local tag_text = fav and fav.tag and fav.tag.text or opts.text or nil
  
  -- Truncate long tag text
  if type(tag_text) == "string" and #tag_text > (opts.max_len or 50) then
    tag_text = tag_text:sub(1, opts.max_len or 50) .. "..."
  end
  
  if fav and fav.locked then
    return { "tf-gui.fave_slot_locked_tooltip", gps_str, tag_text or "" }
  end
  return { "tf-gui.fave_slot_tooltip", gps_str, tag_text or "" }
end

--- Create a styled slot button with icon and tooltip
---@param parent LuaGuiElement Parent element
---@param name string Button name
---@param icon string Icon sprite name
---@param tooltip table|string Tooltip text or localized string
---@param opts table? Additional options
---@return LuaGuiElement? button Created button element
function GuiUtils.create_slot_button(parent, name, icon, tooltip, opts)
  opts = opts or {}
  local sprite = icon
  
  -- Validate sprite if available
  if sprite and sprite ~= "" then
    local is_valid = GuiUtils.validate_sprite(sprite)
    if not is_valid then
      sprite = "utility/questionmark"  -- Fallback sprite
      ErrorHandler.debug_log("Invalid sprite, using fallback", {
        original_sprite = icon,
        fallback = sprite
      })
    end
  end
  
  -- Create button using GuiBase
  local button = GuiBase.create_icon_button(parent, name, sprite, tooltip, opts.style or "tf_slot_button", opts.enabled)
  
  if button and opts.tags then
    button.tags = opts.tags
  end
  
  return button
end

--- Navigate GUI tree to find frame containing element
---@param element LuaGuiElement Starting element
---@return LuaGuiElement? frame Found frame or nil
function GuiUtils.get_gui_frame_by_element(element)
  if not element or not element.valid then return nil end
  
  local current = element
  while current and current.valid do
    if current.type == "frame" then
      return current
    end
    current = current.parent
  end
  return nil
end

--- Find child element by name (recursive search)
---@param parent LuaGuiElement Parent element to search
---@param child_name string Name of child to find
---@return LuaGuiElement? child Found child element or nil
function GuiUtils.find_child_by_name(parent, child_name)
  if not parent or not parent.valid or not child_name then return nil end
  
  -- Direct child check
  if parent[child_name] and parent[child_name].valid then
    return parent[child_name]
  end
  
  -- Recursive search through children
  for _, child in pairs(parent.children) do
    if child.valid then
      if child.name == child_name then
        return child
      end
      
      local found = GuiUtils.find_child_by_name(child, child_name)
      if found then return found end
    end
  end
  
  return nil
end

-- ========================================
-- SPRITE VALIDATION AND DEBUGGING
-- ========================================

--- Validate if a sprite path exists
---@param sprite_path string Sprite path to validate
---@return boolean is_valid True if sprite exists
function GuiUtils.validate_sprite(sprite_path)
  if not sprite_path or sprite_path == "" then return false end
  
  -- Use remote interface if available for sprite validation
  if remote and remote.interfaces and remote.interfaces["__core__"] and remote.interfaces["__core__"].is_valid_sprite_path then
    local success, is_valid = pcall(remote.call, "__core__", "is_valid_sprite_path", sprite_path)
    return success and is_valid
  end
  
  -- Fallback validation - check for common sprite patterns
  local common_sprites = {
    "utility/add", "utility/remove", "utility/close", "utility/refresh",
    "utility/arrow-up", "utility/arrow-down", "utility/arrow-left", "utility/arrow-right",
    "utility/questionmark", "utility/check-mark", "utility/warning"
  }
  
  for _, known_sprite in ipairs(common_sprites) do
    if sprite_path == known_sprite then return true end
  end
  
  -- Check if it's a custom mod sprite
  if sprite_path:find("__TeleportFavorites__") then return true end
  
  return false
end

--- Extract sprite debugging information
---@param sprite_path string Sprite path to debug
---@return table debug_info Sprite debug information
function GuiUtils.debug_sprite_info(sprite_path)
  local info = {
    path = sprite_path,
    exists = GuiUtils.validate_sprite(sprite_path),
    type = "unknown"
  }
  
  if sprite_path then
    if sprite_path:find("utility/") then
      info.type = "utility"
    elseif sprite_path:find("item/") then
      info.type = "item"
    elseif sprite_path:find("entity/") then
      info.type = "entity"
    elseif sprite_path:find("__") then
      info.type = "mod"
    end
  end
  
  return info
end

-- ========================================
-- DYNAMIC STYLE CREATION
-- ========================================

--- Extend a base style with override properties
---@param base_style table Base style to extend
---@param overrides table Properties to override/add
---@return table Extended style definition
function GuiUtils.extend_style(base_style, overrides)
  if type(base_style) ~= "table" or type(overrides) ~= "table" then
    return overrides or {}
  end
  
  local extended_style = {}
  
  -- Copy base style properties
  for key, value in pairs(base_style) do
    if type(value) == "table" then
      extended_style[key] = {}
      for inner_key, inner_value in pairs(value) do
        extended_style[key][inner_key] = inner_value
      end
    else
      extended_style[key] = value
    end
  end
  
  -- Apply overrides
  for key, value in pairs(overrides) do
    if type(value) == "table" and type(extended_style[key]) == "table" then
      -- Deep merge for table values
      for inner_key, inner_value in pairs(value) do
        extended_style[key][inner_key] = inner_value
      end
    else
      extended_style[key] = value
    end
  end
  
  return extended_style
end

--- Create tinted button styles dynamically
---@param base_style table Base style definition
---@param style_configs table Configuration for style variants
---@param gui_style table GUI style table to add styles to
function GuiUtils.create_tinted_button_styles(base_style, style_configs, gui_style)
  if type(base_style) ~= "table" or type(style_configs) ~= "table" or type(gui_style) ~= "table" then
    return
  end
  
  local function create_graphical_set_with_tint(tint)
    return {
      default_graphical_set = {
        base = { position = { 68, 0 }, corner_size = 8, draw_type = "outer", tint = tint }
      },
      hovered_graphical_set = {
        base = { position = { 51, 0 }, corner_size = 8, draw_type = "outer", tint = tint }
      },
      clicked_graphical_set = {
        base = { position = { 34, 0 }, corner_size = 8, draw_type = "outer", tint = tint }
      },
      disabled_graphical_set = {
        base = { position = { 17, 0 }, corner_size = 8, draw_type = "outer", 
                tint = { r = tint.r * 0.5, g = tint.g * 0.5, b = tint.b * 0.5, a = 0.5 } }
      }
    }
  end
  
  for style_name, config in pairs(style_configs) do
    if not gui_style[style_name] then
      gui_style[style_name] = {
        type = "button_style",
        parent = base_style.parent or "button",
        width = config.width or base_style.width,
        height = config.height or base_style.height
      }
      
      -- Apply tinted graphical sets
      if config.tint then
        local tinted_sets = create_graphical_set_with_tint(config.tint)
        for set_name, set_data in pairs(tinted_sets) do
          gui_style[style_name][set_name] = set_data
        end
      end
      
      -- Apply additional style properties
      if config.properties then
        for prop, value in pairs(config.properties) do
          gui_style[style_name][prop] = value
        end
      end
    end
  end
end

--- Create font styles for different sizes
---@param base_font_name string Base font name
---@param sizes table Array of font sizes to create
---@param gui_style table GUI style table to add fonts to
function GuiUtils.create_font_styles(base_font_name, sizes, gui_style)
  if not base_font_name or not sizes or not gui_style then return end
  
  for _, size in ipairs(sizes) do
    local font_style_name = "tf_font_" .. tostring(size)
    if not gui_style[font_style_name] then
      gui_style[font_style_name] = {
        type = "font",
        name = base_font_name,
        size = size
      }
    end
  end
end

-- ========================================
-- RICH TEXT FORMATTING
-- ========================================

local MOD_NAME = "TeleportFavorites"

--- Format a GPS string for display in rich text format
---@param gps_string string GPS string to format
---@return string formatted_gps Rich text formatted GPS string
function GuiUtils.format_gps(gps_string)
  if not gps_string then return "[invalid GPS]" end
  return string.format("[gps=%s]", gps_string)
end

--- Format a chart tag for display in rich text format
---@param chart_tag LuaCustomChartTag Chart tag object
---@param label string? Optional label text (defaults to chart tag text)
---@return string formatted_tag Rich text string representation
function GuiUtils.format_chart_tag(chart_tag, label)
  if not chart_tag or not chart_tag.valid then
    return "[invalid chart tag]"
  end
  
  local text = label or chart_tag.text or ""
  local position_str = ""
  
  if chart_tag.position then
    position_str = string.format("[gps=%d,%d,%d]", 
      math.floor(chart_tag.position.x), 
      math.floor(chart_tag.position.y), 
      chart_tag.surface.index)
  end
  
  -- Format the icon if present
  local icon_str = ""
  if chart_tag.icon and chart_tag.icon.type and chart_tag.icon.name then
    icon_str = string.format("[img=%s/%s]", chart_tag.icon.type, chart_tag.icon.name)
  end
  
  return string.format("%s %s %s", icon_str, text, position_str)
end

--- Generate a position change notification message
---@param player LuaPlayer Player to notify
---@param chart_tag LuaCustomChartTag Chart tag that was changed
---@param old_position MapPosition Previous position
---@param new_position MapPosition New position
---@param surface_index number Surface index
---@return string notification_message Formatted notification message
function GuiUtils.position_change_notification(player, chart_tag, old_position, new_position, surface_index)
  if not player or not player.valid or not old_position or not new_position or not surface_index then
    return "[Invalid position change data]"
  end
  
  local old_gps = string.format("[gps=%d,%d,%d]", 
    math.floor(old_position.x),
    math.floor(old_position.y),
    surface_index)
  
  local new_gps = string.format("[gps=%d,%d,%d]", 
    math.floor(new_position.x),
    math.floor(new_position.y),
    surface_index)
  
  local tag_text = ""
  local icon_str = ""
  
  if chart_tag and chart_tag.valid then
    tag_text = chart_tag.text or ""
    
    if chart_tag.icon and chart_tag.icon.type and chart_tag.icon.name then
      icon_str = string.format("[img=%s/%s] ", chart_tag.icon.type, chart_tag.icon.name)
    end
  end
  
  return string.format("[%s] %sLocation %s changed from %s to %s", 
    MOD_NAME, icon_str, tag_text, old_gps, new_gps)
end

--- Format a deletion prevention message
---@param chart_tag LuaCustomChartTag Chart tag that couldn't be deleted
---@return string deletion_message Formatted message explaining why deletion failed
function GuiUtils.deletion_prevention_notification(chart_tag)
  if not chart_tag or not chart_tag.valid then
    return "[Invalid chart tag data]"
  end
  
  local tag_text = chart_tag.text or ""
  local icon_str = ""
  
  if chart_tag.icon and chart_tag.icon.type and chart_tag.icon.name then
    icon_str = string.format("[img=%s/%s] ", chart_tag.icon.type, chart_tag.icon.name)
  end
  
  local position_str = ""
  if chart_tag.position then
    position_str = string.format("[gps=%d,%d,%d]", 
      math.floor(chart_tag.position.x), 
      math.floor(chart_tag.position.y), 
      chart_tag.surface.index)
  end
  
  return string.format("[%s] %s%s %s cannot be deleted because it is favorited by other players", 
    MOD_NAME, icon_str, tag_text, position_str)
end

--- Generate a tag relocation notification message for terrain changes
---@param chart_tag LuaCustomChartTag Chart tag that was relocated
---@param old_position MapPosition Previous position
---@param new_position MapPosition New position
---@return string relocation_message Formatted relocation message
function GuiUtils.tag_relocated_notification(chart_tag, old_position, new_position)
  if not chart_tag or not chart_tag.valid or not old_position or not new_position then
    return "[Invalid relocation data]"
  end
  
  local surface_index = chart_tag.surface and chart_tag.surface.index or 1
  local tag_text = chart_tag.text or "Tag"
  local icon_str = ""
  
  if chart_tag.icon and chart_tag.icon.type and chart_tag.icon.name then
    icon_str = string.format("[img=%s/%s] ", chart_tag.icon.type, chart_tag.icon.name)
  end
  
  local old_position_str = string.format("[gps=%d,%d,%d]", 
    math.floor(old_position.x), math.floor(old_position.y), surface_index)
  local new_position_str = string.format("[gps=%d,%d,%d]", 
    math.floor(new_position.x), math.floor(new_position.y), surface_index)
  
  return string.format("[%s] %s%s has been relocated from %s to %s due to terrain changes", 
    MOD_NAME, icon_str, tag_text, old_position_str, new_position_str)
end

-- ========================================
-- GUI STATE MANAGEMENT
-- ========================================

--- Validate GUI element exists and is valid
---@param element LuaGuiElement? Element to validate
---@return boolean is_valid True if element is valid
function GuiUtils.validate_gui_element(element)
  return element ~= nil and element.valid == true
end

--- Set GUI element visibility with validation
---@param element LuaGuiElement? Element to modify
---@param visible boolean Visibility state
---@return boolean success True if successfully set
function GuiUtils.set_element_visibility(element, visible)
  if not GuiUtils.validate_gui_element(element) then return false end
  
  element.visible = visible
  return true
end

--- Set GUI element text with validation
---@param element LuaGuiElement? Element to modify
---@param text string Text to set
---@return boolean success True if successfully set
function GuiUtils.set_element_text(element, text)
  if not GuiUtils.validate_gui_element(element) then return false end
  
  if element.type == "label" or element.type == "button" then
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
function GuiUtils.apply_style_properties(element, style_props)
  if not GuiUtils.validate_gui_element(element) or type(style_props) ~= "table" then
    return false
  end
  
  local success, error_msg = pcall(function()
    for prop, value in pairs(style_props) do
      element.style[prop] = value
    end
  end)
  
  if not success then
    ErrorHandler.debug_log("Failed to apply style properties", {
      element_name = element.name,
      element_type = element.type,
      error = error_msg
    })
  end
  
  return success
end

-- ========================================
-- ACCESSIBILITY HELPERS
-- ========================================

--- Create accessible tooltip with screen reader support
---@param base_tooltip string|table Base tooltip content
---@param context string? Additional context for screen readers
---@return table accessible_tooltip Enhanced tooltip for accessibility
function GuiUtils.create_accessible_tooltip(base_tooltip, context)
  local tooltip = base_tooltip
  
  if context then
    if type(tooltip) == "string" then
      tooltip = tooltip .. " (" .. context .. ")"
    elseif type(tooltip) == "table" then
      table.insert(tooltip, " (" .. context .. ")")
    end
  end
  
  return tooltip
end

--- Add ARIA-like attributes for screen reader compatibility
---@param element LuaGuiElement? Element to enhance
---@param role string ARIA role (button, label, textbox, etc.)
---@param description string? Additional description
function GuiUtils.add_accessibility_attributes(element, role, description)
  if not GuiUtils.validate_gui_element(element) then return end
  
  -- Enhance tooltip for screen readers
  local current_tooltip = element.tooltip or ""
  local enhanced_tooltip = role
  
  if description then
    enhanced_tooltip = enhanced_tooltip .. ": " .. description
  end
  
  if current_tooltip ~= "" then
    enhanced_tooltip = enhanced_tooltip .. " - " .. tostring(current_tooltip)
  end
  
  element.tooltip = enhanced_tooltip
end

return GuiUtils
