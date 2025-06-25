---@diagnostic disable: undefined-global
--[[
GUI Accessibility Utilities for TeleportFavorites
===============================================
Module: core/utils/gui_accessibility.lua

Provides accessibility and screen reader support utilities for GUI elements.

Functions:
- create_accessible_tooltip() - Create tooltip with screen reader support
- add_accessibility_attributes() - Add ARIA-like attributes
- get_or_create_gui_flow_from_gui_top() - Get or create main GUI flow
]]

local GuiValidation = require("core.utils.gui_validation")

---@class GuiAccessibility
local GuiAccessibility = {}

--- Create accessible tooltip with screen reader support
---@param base_tooltip string|table Base tooltip content
---@param context string? Additional context for screen readers
---@return string|table accessible_tooltip Enhanced tooltip for accessibility
function GuiAccessibility.create_accessible_tooltip(base_tooltip, context)
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
function GuiAccessibility.add_accessibility_attributes(element, role, description)
  if not GuiValidation.validate_gui_element(element) then return end
  ---@cast element -nil
  
  -- Enhance tooltip for screen readers
  local current_tooltip = element.tooltip or ""
  local enhanced_tooltip = role
  
  if description then
    enhanced_tooltip = enhanced_tooltip .. ": " .. description
  end
  
  if current_tooltip ~= "" then
    enhanced_tooltip = enhanced_tooltip .. " - " .. tostring(current_tooltip)
  end
  
  ---@diagnostic disable-next-line: assign-type-mismatch
  element.tooltip = enhanced_tooltip
end

--- Get or create the main GUI flow in player's top GUI
--- This is the shared parent container for all TeleportFavorites GUI elements
---@param player LuaPlayer The player whose GUI to access
---@return LuaGuiElement The main GUI flow element
function GuiAccessibility.get_or_create_gui_flow_from_gui_top(player)
  local top = player.gui.top
  ---@diagnostic disable-next-line: undefined-field
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

return GuiAccessibility
