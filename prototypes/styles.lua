--[[
Centralized GUI style prototypes for TeleportFavorites
=====================================================
File: prototypes/styles.lua

Defines custom GUI styles for use in runtime GUIs, ensuring a consistent, vanilla-aligned look across the mod.

Features:
- te_tr_favorite_label: Bold, fixed-width label style for favorite/tag editor GUIs.
- tf_slot_button: Custom slot button style for all TeleportFavorites GUIs, inheriting from vanilla slot_button with tweaks for font, size, and colors.
- All styles are registered on data.raw["gui-style"].default for use in runtime and control scripts.

Usage:
- Reference these styles by name (e.g., "tf_slot_button") in runtime GUI code.
- Ensures maintainability and a native Factorio look for all custom GUIs.
--]]

local Constants = require("constants")

---@diagnostic disable-next-line: undefined-global
local gui_style = data.raw["gui-style"].default

-- Bold, fixed-width label style for favorites/tag editor
gui_style.te_tr_favorite_label = {
  type = "label_style",
  parent = "label",
  single_line = true,
  horizontally_stretchable = "off",
  vertically_stretchable = "off",
  font = "default-bold",
  minimal_width = 100,
  maximal_width = 100
}

-- Custom slot button style for all TeleportFavorites GUIs
---@diagnostic disable-next-line: undefined-global
local gui_style = data.raw["gui-style"].default

-- Inherit from vanilla slot_button, but allow for future tweaks
if not gui_style.tf_slot_button then
  ---@type table
  local base = {}
  for k, v in pairs(gui_style.slot_button) do base[k] = v end
  base.font = "default-bold"
  base.width = 36
  base.height = 36
  base.default_font_color = {r=1, g=1, b=1}
  base.hovered_font_color = {r=1, g=0.9, b=0.5}
  base.clicked_font_color = {r=1, g=0.8, b=0.2}
  base.padding = 0
  base.margin = 0
  gui_style.tf_slot_button = base
end
