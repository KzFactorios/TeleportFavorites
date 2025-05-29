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
if not gui_style.tf_slot_button then
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

-- Custom slot button style for drag highlight (blue border)
if not gui_style.tf_slot_button_dragged then
  local base = {}
  for k, v in pairs(gui_style.tf_slot_button) do base[k] = v end
  base.default_graphical_set = {
    base = {position = {0, 0}, corner_size = 8, tint = {r=0.2, g=0.7, b=1, a=1}}
  }
  gui_style.tf_slot_button_dragged = base
end

-- Custom slot button style for locked highlight (orange border)
if not gui_style.tf_slot_button_locked then
  local base = {}
  for k, v in pairs(gui_style.tf_slot_button) do base[k] = v end
  base.default_graphical_set = {
    base = {position = {0, 0}, corner_size = 8, tint = {r=1, g=0.5, b=0, a=1}}
  }
  gui_style.tf_slot_button_locked = base
end

-- Custom slot button style for drag target (yellow border)
if not gui_style.tf_slot_button_drag_target then
  local base = {}
  for k, v in pairs(gui_style.tf_slot_button) do base[k] = v end
  base.default_graphical_set = {
    base = {position = {0, 0}, corner_size = 8, tint = {r=1, g=1, b=0.2, a=1}}
  }
  gui_style.tf_slot_button_drag_target = base
end

-- Titlebar flow style for tag editor dialogs (matches vanilla titlebar row)
gui_style.frame_titlebar_flow = {
  type = "horizontal_flow_style",
  parent = "horizontal_flow",
  horizontally_stretchable = "on",
  vertically_stretchable = "off",
  top_padding = 0,
  bottom_padding = 0,
  left_padding = 8,
  right_padding = 4,
  height = 32,
  vertical_align = "center",
  use_header_filler = true
}

-- Data Viewer GUI styles

-- Frame style for data_viewer_frame
if not gui_style.data_viewer_frame then
  gui_style.data_viewer_frame = {
    type = "frame_style",
    parent = "frame",
    width = 1000,
    vertically_stretchable = "on",
    padding = 0,
    margin = 0
  }
end

-- Inner flow style for data_viewer_inner_flow
if not gui_style.data_viewer_inner_flow then
  gui_style.data_viewer_inner_flow = {
    type = "vertical_flow_style",
    parent = "vertical_flow",
    horizontally_stretchable = "on",
    vertically_stretchable = "on",
    padding = 0,
    margin = 0
  }
end

-- Titlebar flow style for data_viewer_titlebar_flow
if not gui_style.data_viewer_titlebar_flow then
  gui_style.data_viewer_titlebar_flow = {
    type = "horizontal_flow_style",
    parent = "frame_titlebar_flow",
    horizontally_stretchable = "on",
    vertically_stretchable = "off",
    height = 32,
    vertical_align = "center"
  }
end

-- Tabs flow style for data_viewer_tabs_flow
if not gui_style.data_viewer_tabs_flow then
  gui_style.data_viewer_tabs_flow = {
    type = "horizontal_flow_style",
    parent = "horizontal_flow",
    horizontally_stretchable = "on",
    vertically_stretchable = "off",
    padding = 0,
    margin = 0
  }
end

-- Content flow style for data_viewer_content_flow
if not gui_style.data_viewer_content_flow then
  gui_style.data_viewer_content_flow = {
    type = "vertical_flow_style",
    parent = "vertical_flow",
    horizontally_stretchable = "on",
    vertically_stretchable = "on",
    padding = 0,
    margin = 0
  }
end

-- Table style for data_viewer_table
if not gui_style.data_viewer_table then
  gui_style.data_viewer_table = {
    type = "table_style",
    parent = "table",
    horizontally_stretchable = "on",
    vertically_stretchable = "on",
    cell_padding = 2,
    cell_spacing = 0,
    use_header_filler = false
  }
end
