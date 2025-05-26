--[[
Centralized GUI style and layout helpers for TeleportFavorites
=============================================================
Module: gui/styles.lua

Provides runtime style presets and layout helpers for consistent, vanilla-aligned GUIs across the mod.

Features:
- Standardized padding, margin, and alignment values (multiples of 4px, matching vanilla Factorio).
- Named style tables for common label/button/flow usage.
- Helper functions for creating and customizing button styles and horizontal flows.
- Ensures maintainability and a native Factorio look for all GUIs.

API:
- Style.padding, Style.margin: Tables of standard size values.
- Style.align: Table of alignment string constants.
- Style.favorite_label: Standard label style for favorite/tag editor GUIs.
- Style.button(overrides): Returns a button style table, optionally merged with overrides.
- Style.add_horizontal_flow(parent, name, opts): Adds a horizontal flow with standard spacing and alignment.

All helpers and tables are intended for use in GUI modules to keep layout and style consistent.
--]]

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

--- Alignment helpers (string constants for alignment properties)
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
-- @param overrides table|nil: Table of style properties to override
-- @return table: Button style table
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
-- @param parent LuaGuiElement: Parent element
-- @param name string: Name of the flow
-- @param opts table|nil: Optional overrides for alignment, padding, margin
-- @return LuaGuiElement: The created flow
function Style.add_horizontal_flow(parent, name, opts)
  opts = opts or {}
  return parent:add{
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