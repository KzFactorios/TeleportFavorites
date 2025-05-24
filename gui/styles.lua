-- Centralized GUI style and layout helpers for TeleportFavorites
-- This module provides runtime style presets and layout helpers for consistent, vanilla-aligned GUIs.
-- Use these helpers in all GUI modules to ensure maintainability and a native Factorio look.

local Style = {}

--- Vanilla-aligned padding and margin presets (multiples of 4px)
Style.padding = {
  small = 4,
  default = 8,
  large = 12,
}

Style.margin = {
  small = 4,
  default = 8,
  large = 12,
}

--- Alignment helpers
Style.align = {
  left = "left",
  center = "center",
  right = "right",
  top = "top",
  middle = "middle",
  bottom = "bottom",
}

--- Standard label style for favorite/tag editor (matches prototypes/styles.lua)
Style.favorite_label = {
  type = "label_style",
  parent = "label",
  single_line = true,
  horizontally_stretchable = "off",
  vertically_stretchable = "off",
  font = "default-bold",
  minimal_width = 100,
  maximal_width = 100,
}

--- Helper to apply vanilla button style with optional overrides
---@param overrides table|nil
---@return table
function Style.button(overrides)
  local base = {
    type = "button_style",
    parent = "button",
    horizontally_stretchable = "on",
    vertically_stretchable = "on",
    padding = Style.padding.default,
    margin = Style.margin.small,
  }
  if overrides then
    for k, v in pairs(overrides) do base[k] = v end
  end
  return base
end

--- Helper to create a horizontal flow with standard spacing
---@param parent LuaGuiElement
---@param name string
---@param opts table|nil
---@return LuaGuiElement
function Style.add_horizontal_flow(parent, name, opts)
  opts = opts or {}
  return parent.add{
    type = "flow",
    name = name,
    direction = "horizontal",
    style_mods = {
      horizontally_stretchable = opts.horizontally_stretchable or "on",
      vertical_align = opts.vertical_align or Style.align.middle,
      padding = opts.padding or Style.padding.default,
      margin = opts.margin or Style.margin.small,
    }
  }
end

return Style