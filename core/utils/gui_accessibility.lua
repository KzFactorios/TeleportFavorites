---@diagnostic disable: undefined-global
--[[
GUI Accessibility Utilities for TeleportFavorites
===============================================
Module: core/utils/gui_accessibility.lua

Provides accessibility and screen reader support utilities for GUI elements.

Functions:
- get_or_create_gui_flow_from_gui_top() - Get or create main GUI flow
]]

local GuiValidation = require("core.utils.gui_validation")

---@class GuiAccessibility
local GuiAccessibility = {}

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
