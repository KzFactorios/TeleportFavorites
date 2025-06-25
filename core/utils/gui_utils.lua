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
local LocaleUtils = require("core.utils.locale_utils")
local Enum = require("prototypes.enums.enum")
local GPSUtils = require("core.utils.gps_utils")

---@class GuiUtils
local GuiUtils = {}

local function safe_player_print(player, message)
  if player and player.valid and type(player.print) == "function" then
    pcall(function() player.print(message) end)
  end
end

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

--- Safe GUI frame destruction
---@param parent LuaGuiElement Parent element containing the frame
---@param frame_name string Name of the frame to destroy
function GuiUtils.safe_destroy_frame(parent, frame_name)
  if not parent or not frame_name then return end
  
  if parent[frame_name] and parent[frame_name].valid and type(parent[frame_name].destroy) == "function" then
    parent[frame_name].destroy()
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
  local tag_text = fav and fav.tag and fav.tag.chart_tag and fav.tag.chart_tag.text or opts.text or nil
  
  -- Truncate long tag text
  if type(tag_text) == "string" and #tag_text > (opts.max_len or 50) then
    tag_text = tag_text:sub(1, opts.max_len or 50) .. "..."
  end

  if not tag_text or tag_text == "" then
    return { "tf-gui.fave_slot_tooltip_one", GPSUtils.coords_string_from_gps(gps_str) }
  else
    return { "tf-gui.fave_slot_tooltip_both", tag_text or "", gps_str }
  end

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
      sprite = Enum.SpriteEnum.QUESTION_MARK  -- Fallback sprite
      ErrorHandler.debug_log("Invalid sprite, using fallback", {
        original_sprite = icon,
        fallback = sprite
      })
    end
  end
    -- FACTORIO ENGINE QUIRK: The sprite-button may require a non-empty caption for drag/drop to work properly.
  -- This is an engine limitation. We DON'T set the caption here to allow the caller to set it appropriately.
  -- This is a strict project policy: slot number logic must use the button name, never the caption.
  local button = GuiBase.create_icon_button(parent, name, sprite, tooltip, opts.style or "tf_slot_button", opts.enabled)
  -- NOTE: We deliberately do NOT set button.caption here anymore due to Factorio engine quirks
  
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
  local frames_checked = {}
  
  while current and current.valid do
    if current.type == "frame" then
      local name = current.name or ""
      table.insert(frames_checked, name)
      
      -- Debug logging
      ErrorHandler.debug_log("GuiUtils.get_gui_frame_by_element: Checking frame", {
        frame_name = name,
        target_tag_editor = Enum.GuiEnum.GUI_FRAME.TAG_EDITOR,
        target_data_viewer = Enum.GuiEnum.GUI_FRAME.DATA_VIEWER,
        target_fave_bar = Enum.GuiEnum.GUI_FRAME.FAVE_BAR,
        target_confirm_dialog = Enum.GuiEnum.GUI_FRAME.TAG_EDITOR_DELETE_CONFIRM
      })
      
      if name == Enum.GuiEnum.GUI_FRAME.TAG_EDITOR or 
         name == Enum.GuiEnum.GUI_FRAME.DATA_VIEWER or 
         name == Enum.GuiEnum.GUI_FRAME.FAVE_BAR or
         name == Enum.GuiEnum.GUI_FRAME.TAG_EDITOR_DELETE_CONFIRM then
        ErrorHandler.debug_log("GuiUtils.get_gui_frame_by_element: Found main frame", {
          found_frame = name
        })
        return current
      end
    end
    current = current.parent
  end
  
  ErrorHandler.debug_log("GuiUtils.get_gui_frame_by_element: No main frame found", {
    original_element = element and element.name or "nil",
    frames_checked = frames_checked
  })
  
  -- Fallback: if we didn't find a main frame but we found frames, 
  -- return the topmost frame (last in hierarchy)
  if #frames_checked > 0 then
    ErrorHandler.debug_log("GuiUtils.get_gui_frame_by_element: Using fallback - returning topmost frame", {
      fallback_frame = frames_checked[#frames_checked]
    })
    -- Go back up to find the topmost frame
    current = element
    local topmost_frame = nil
    while current and current.valid do
      if current.type == "frame" then
        topmost_frame = current
      end
      current = current.parent
    end
    return topmost_frame
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
    if success and is_valid then
      return true
    else
      return false
    end
  end
  -- If remote is not available (data stage or fallback), optimistically allow any non-empty sprite path
  return true
end

--- Extract sprite debugging information
---@param sprite_path string Sprite path to debug
---@return table debug_info Sprite debug information
function GuiUtils.debug_sprite_info(sprite_path)
  if not sprite_path then return {} end
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
  if not gps_string then return LocaleUtils.get_error_string(nil, "invalid_gps_fallback") end
  return string.format("[gps=%s]", gps_string)
end

--- Format a chart tag for display in rich text format
---@param chart_tag LuaCustomChartTag Chart tag object
---@param label string? Optional label text (defaults to chart tag text)
---@return string formatted_tag Rich text string representation
function GuiUtils.format_chart_tag(chart_tag, label)
  if not chart_tag or not chart_tag.valid then
    return LocaleUtils.get_error_string(nil, "invalid_chart_tag_fallback")
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
---@return string notification_message Formatted notification message
function GuiUtils.position_change_notification(player, chart_tag, old_position, new_position)
  if not player or not player.valid or not old_position or not new_position then
    return LocaleUtils.get_error_string(player, "invalid_position_change_fallback")
  end
  
  local surface_index = player.surface.index
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
  
  return LocaleUtils.get_error_string(player, "location_changed", {icon_str .. tag_text, old_gps, new_gps})
end

--- Format a deletion prevention message
---@param chart_tag LuaCustomChartTag Chart tag that couldn't be deleted
---@return string deletion_message Formatted message explaining why deletion failed
function GuiUtils.deletion_prevention_notification(chart_tag)
  if not chart_tag or not chart_tag.valid then
    return LocaleUtils.get_error_string(nil, "invalid_chart_tag_fallback")
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
  
  return LocaleUtils.get_error_string(nil, "tag_deletion_prevented", {icon_str .. tag_text .. " " .. position_str})
end

--- Generate a tag relocation notification message for terrain changes
---@param chart_tag LuaCustomChartTag Chart tag that was relocated
---@param old_position MapPosition Previous position
---@param new_position MapPosition New position
---@return string relocation_message Formatted relocation message
function GuiUtils.tag_relocated_notification(chart_tag, old_position, new_position)
  if not chart_tag or not chart_tag.valid or not old_position or not new_position then
    return LocaleUtils.get_error_string(nil, "invalid_relocation_data_fallback")
  end
  
  local surface_index = chart_tag.surface and chart_tag.surface.index or 1
  local tag_text = chart_tag.text or ""
  local icon_str = ""
  
  if chart_tag.icon and chart_tag.icon.type and chart_tag.icon.name then
    icon_str = string.format("[img=%s/%s] ", chart_tag.icon.type, chart_tag.icon.name)
  end
  
  local old_position_str = string.format("[gps=%d,%d,%d]", 
    math.floor(old_position.x), math.floor(old_position.y), surface_index)
  local new_position_str = string.format("[gps=%d,%d,%d]", 
    math.floor(new_position.x), math.floor(new_position.y), surface_index)
  
  return LocaleUtils.get_error_string(nil, "tag_relocated_terrain", {icon_str .. tag_text, old_position_str, new_position_str})
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

--- Get or create the main GUI flow in player's top GUI
--- This is the shared parent container for all TeleportFavorites GUI elements
---@param player LuaPlayer The player whose GUI to access
---@return LuaGuiElement The main GUI flow element
function GuiUtils.get_or_create_gui_flow_from_gui_top(player)
  local top = player.gui.top
  local flow = top and top.tf_main_gui_flow
  if not (flow and flow.valid) then
    flow = top.add {
      type = "flow",
      name = "tf_main_gui_flow",
      direction = "vertical", 
      style = "vertical_flow" -- vanilla style, stretches to fit children, not scrollable
    }
    -- Do NOT set .style fields at runtime for flows; use style at creation only
  end
  return flow
end

-- ========================================
-- SPRITE PATH BUILDING, VALIDATION, AND FALLBACK (CENTRALIZED)
-- ========================================

--- Build and validate a sprite path from icon data (table or string), with fallback and debug logging
---@param icon table|string|nil Icon table (with .type/.name) or string path
---@param opts table|nil Options: { fallback?: string, log_context?: table, allow_blank?: boolean }
---@return string sprite_path Valid sprite path (never blank unless allow_blank)
---@return boolean used_fallback True if fallback was used
---@return table debug_info Debug info for logging
function GuiUtils.get_validated_sprite_path(icon, opts)
  opts = opts or {}
  local fallback = opts.fallback or Enum.SpriteEnum.PIN
  local allow_blank = opts.allow_blank or false
  local log_context = opts.log_context or {}
  local sprite_path, used_fallback, debug_info
  used_fallback = false
  debug_info = { original_icon = icon, fallback = fallback }

  -- Build sprite path from icon
  if not icon or icon == "" then
    sprite_path = allow_blank and "" or fallback
    used_fallback = not allow_blank
    debug_info.reason = "icon is nil or blank"
  elseif type(icon) == "string" then
    sprite_path = icon
  elseif type(icon) == "table" then
    if icon.type and icon.type ~= "" and icon.name and icon.name ~= "" then
      -- Special handling for virtual signals: use 'virtual-signal/' not 'virtual/'
      if icon.type == "virtual" or icon.type == "virtual-signal" then
        sprite_path = "virtual-signal/" .. icon.name
        debug_info.reason = "icon type is virtual or virtual-signal, using virtual-signal/ prefix"
      else
        sprite_path = icon.type .. "/" .. icon.name
      end
    elseif icon.name and icon.name ~= "" then
      -- Prefer item/ as the default fallback for unknown type
      sprite_path = "item/" .. icon.name
      debug_info.reason = "icon missing type, defaulted to item/"
    else
      sprite_path = fallback
      used_fallback = true
      debug_info.reason = "icon table missing name"
    end
  else
    sprite_path = fallback
    used_fallback = true
    debug_info.reason = "icon not string or table"
  end

  -- Validate sprite path
  if sprite_path ~= "" and not GuiUtils.validate_sprite(tostring(sprite_path)) then
    local icon_str = (debug_info.original_icon and basic_helpers and basic_helpers.table_to_json and type(basic_helpers.table_to_json) == "function")
      and basic_helpers.table_to_json(debug_info.original_icon)
      or tostring(debug_info.original_icon)
    debug_info.reason = icon_str .. ": " .. (debug_info.reason or "") .. ", sprite invalid"
    sprite_path = fallback
    used_fallback = true
  end

  if used_fallback == true then
    ErrorHandler.debug_log("[SPRITE] Fallback used in get_validated_sprite_path", {
      sprite_path = sprite_path,
      debug_info = debug_info,
      log_context = log_context
    })
  end

  return sprite_path, used_fallback, debug_info
end

return GuiUtils
