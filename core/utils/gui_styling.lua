---@diagnostic disable: undefined-global
--[[
GUI Styling Utilities for TeleportFavorites
==========================================
Module: core/utils/gui_styling.lua

Provides style creation and management utilities for GUI elements.

Functions:
- extend_style() - Extend base style with override properties
- create_tinted_button_styles() - Create tinted button styles dynamically
- create_font_styles() - Create font styles for different sizes
- create_slot_button() - Create a styled slot button with icon and tooltip
]]

---@class GuiStyling
local GuiStyling = {}

--- Extend a base style with override properties
---@param base_style table Base style to extend
---@param overrides table Properties to override/add
---@return table Extended style definition
function GuiStyling.extend_style(base_style, overrides)
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
function GuiStyling.create_tinted_button_styles(base_style, style_configs, gui_style)
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
function GuiStyling.create_font_styles(base_font_name, sizes, gui_style)
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
-- BUTTON AND ELEMENT CREATION
-- ========================================

--- Create a styled slot button with icon and tooltip
---@param parent LuaGuiElement Parent GUI element
---@param name string Button name
---@param icon string|nil Icon sprite path
---@param tooltip string|nil Button tooltip
---@param opts table? Options table with style overrides
---@return LuaGuiElement Created button element
function GuiStyling.create_slot_button(parent, name, icon, tooltip, opts)
  local GuiBase = require("gui.gui_base")
  local Enum = require("prototypes.enums.enum")
  
  opts = opts or {}
  local style = opts.style or "tf_fave_slot_button"
  local sprite = icon or Enum.SpriteEnum.EMPTY
  
  local button = GuiBase.create_sprite_button(parent, name, sprite, tooltip, style)
  
  -- Apply any style overrides
  if opts.style_overrides then
    local GuiValidation = require("core.utils.gui_validation")
    GuiValidation.apply_style_properties(button, opts.style_overrides)
  end
  
  return button
end

return GuiStyling
