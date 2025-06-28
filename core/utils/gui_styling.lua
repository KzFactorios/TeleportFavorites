---@diagnostic disable: undefined-global
--[[
GUI Styling Utilities for TeleportFavorites
==========================================
Module: core/utils/gui_styling.lua

Provides style creation and management utilities for GUI elements.
]]

---@class GuiStyling
local GuiStyling = {}

local GuiBase = require("gui.gui_base")

--- Create a styled slot button with icon and tooltip
---@param parent LuaGuiElement Parent GUI element
---@param name string Button name
---@param icon string|nil Icon sprite path
---@param tooltip LocalisedString|string|nil Button tooltip
---@param opts table? Options table with style overrides
---@return LuaGuiElement Created button element
function GuiStyling.create_slot_button(parent, name, icon, tooltip, opts)
  opts = opts or {}
  local style = opts.style or "tf_fave_slot_button"
  local sprite = icon or ""
  local button = GuiBase.create_sprite_button(parent, name, sprite, tooltip, style)
  
  -- Apply any style overrides
  if opts.style_overrides then
    local GuiValidation = require("core.utils.gui_validation")
    GuiValidation.apply_style_properties(button, opts.style_overrides)
  end
  
  return button
end

return GuiStyling
