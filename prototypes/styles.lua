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

local blue = { r = 0.502, g = 0.808, b = 0.941, a = 1 }
local green = { r = 0, g = 1.0, b = 0, a = 1 }    -- #ffa500
local orange = { r = 1, g = 0.647, b = 0, a = 1 } -- #ffa500
local red = { r = 0.502, g = 0.808, b = 0.941, a = 1 }

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
  base.width = 30
  base.height = 30
  gui_style.tf_slot_button = base
end

-- Custom slot button style for drag highlight (blue border)
if not gui_style.tf_slot_button_dragged then
  local base = {}
  for k, v in pairs(gui_style.slot_button) do base[k] = v end
  base.default_graphical_set = {
    base = { position = { 68, 0 }, corner_size = 8, draw_type = "outer", tint = { r = 0.2, g = 0.7, b = 1, a = 1 } }
  }
  base.hovered_graphical_set = {
    base = { position = { 51, 0 }, corner_size = 8, draw_type = "outer", tint = { r = 0.2, g = 0.7, b = 1, a = 1 } }
  }
  base.clicked_graphical_set = {
    base = { position = { 34, 0 }, corner_size = 8, draw_type = "outer", tint = { r = 0.2, g = 0.7, b = 1, a = 1 } }
  }
  base.disabled_graphical_set = {
    base = { position = { 17, 0 }, corner_size = 8, draw_type = "outer", tint = { r = 0.2, g = 0.7, b = 1, a = 0.5 } }
  }
  gui_style.tf_slot_button_dragged = base
end

-- Custom slot button style for locked highlight (orange border)
if not gui_style.tf_slot_button_locked then
  local base = {}
  for k, v in pairs(gui_style.slot_button) do base[k] = v end
  base.default_graphical_set = {
    base = { position = { 68, 0 }, corner_size = 8, draw_type = "outer", tint = { r = 1, g = 0.5, b = 0, a = 1 } }
  }
  base.hovered_graphical_set = {
    base = { position = { 51, 0 }, corner_size = 8, draw_type = "outer", tint = { r = 1, g = 0.5, b = 0, a = 1 } }
  }
  base.clicked_graphical_set = {
    base = { position = { 34, 0 }, corner_size = 8, draw_type = "outer", tint = { r = 1, g = 0.5, b = 0, a = 1 } }
  }
  base.disabled_graphical_set = {
    base = { position = { 17, 0 }, corner_size = 8, draw_type = "outer", tint = { r = 1, g = 0.5, b = 0, a = 0.5 } }
  }
  gui_style.tf_slot_button_locked = base
end

-- Custom slot button style for drag target (yellow border)
if not gui_style.tf_slot_button_drag_target then
  local base = {}
  for k, v in pairs(gui_style.slot_button) do base[k] = v end
  base.default_graphical_set = {
    base = { position = { 68, 0 }, corner_size = 8, draw_type = "outer", tint = { r = 1, g = 1, b = 0.2, a = 1 } }
  }
  base.hovered_graphical_set = {
    base = { position = { 51, 0 }, corner_size = 8, draw_type = "outer", tint = { r = 1, g = 1, b = 0.2, a = 1 } }
  }
  base.clicked_graphical_set = {
    base = { position = { 34, 0 }, corner_size = 8, draw_type = "outer", tint = { r = 1, g = 1, b = 0.2, a = 1 } }
  }
  base.disabled_graphical_set = {
    base = { position = { 17, 0 }, corner_size = 8, draw_type = "outer", tint = { r = 1, g = 1, b = 0.2, a = 0.5 } }
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

-- Frame style for data_viewer_frame (make resizable)
if not gui_style.data_viewer_frame then
  gui_style.data_viewer_frame = {
    type = "frame_style",
    parent = "frame",
    width = 1000,
    horizontally_stretchable = "on",
    vertically_stretchable = "on",
    minimal_width = 600,
    maximal_width = 2000,
    minimal_height = 200,
    maximal_height = 1200,
    resize_row = true, -- allow resizing
    resize_column = true, -- allow resizing
    padding = 0,
    margin = 0,
    right_padding = 12
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

-- Scroll-pane style for data_viewer_content_scroll (make resizable)
if not gui_style.data_viewer_content_scroll then
  gui_style.data_viewer_content_scroll = {
    type = "scroll_pane_style",
    parent = "scroll_pane",
    horizontally_stretchable = "on",
    vertically_stretchable = "on",
    minimal_width = 600,
    maximal_width = 2000,
    minimal_height = 200,
    maximal_height = 1200,
    width = 1000,
    height = 600,
    vertical_scroll_policy = "auto",
    horizontal_scroll_policy = "auto"
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

-- Custom slot button style with small font, orange text, and bottom-aligned caption
if not gui_style.tf_slot_button_smallfont then
  local base = {}
  for k, v in pairs(gui_style.slot_button) do base[k] = v end
  -- Remove font color properties from base if present
  base.font_color = nil
  base.selected_font_color = nil
  base.hovered_font_color = nil
  base.clicked_font_color = nil
  base.disabled_font_color = nil
  -- Now set our custom properties
  base.type = "button_style"
  base.font = "default-small"
  base.horizontal_align = "center"
  base.vertical_align = "bottom"
  base.font_color = { r = 1, g = 0.647, b = 0, a = 1 } -- Factorio orange #ffa500
  base.selected_font_color = { r = 1, g = 0.647, b = 0, a = 1 }
  base.hovered_font_color = { r = 1, g = 0.647, b = 0, a = 1 }
  base.clicked_font_color = { r = 1, g = 0.647, b = 0, a = 1 }
  base.disabled_font_color = { r = 1, g = 0.647, b = 0, a = 0.5 }
  base.top_padding = 0
  base.bottom_padding = 2
  base.size = { 36, 36 }
  gui_style.tf_slot_button_smallfont = base
end

-- Custom frame style for the favorites slots row (for frames)
if not gui_style.tf_fave_slots_row then
  gui_style.tf_fave_slots_row = {
    type = "frame_style",
    parent = "inside_deep_frame",
    vertically_stretchable = "off",
    horizontally_stretchable = "on",
    left_margin = 0,
    padding = 4,
    margin = 0
  }
end

-- Custom flow style for the favorites slots row (for flows)
if not gui_style.tf_fave_slots_row_flow then
  gui_style.tf_fave_slots_row_flow = {
    type = "horizontal_flow_style",
    parent = "horizontal_flow",
    vertically_stretchable = "off",
    horizontally_stretchable = "on",
    left_margin = 0,
    padding = 4,
    margin = 0
  }
end

-- Custom frame style for the favorites toggle container
if not gui_style.tf_fave_toggle_container then
  gui_style.tf_fave_toggle_container = {
    type = "frame_style",
    parent = "inside_deep_frame", -- match the slots row background
    graphical_set = nil, -- use parent's background
    padding = 0,
    margin = 0,
    horizontally_stretchable = "off",
    vertically_stretchable = "off"
  }
end

-- Custom style for the favorite bar visible toggle button (no slot background)
if not gui_style.tf_fave_toggle_button then
  local base = {}
  for k, v in pairs(gui_style.slot_button) do base[k] = v end
  base.default_graphical_set = { base = { type = "none" } }
  base.hovered_graphical_set = { base = { type = "none" } }
  base.clicked_graphical_set = { base = { type = "none" } }
  base.disabled_graphical_set = { base = { type = "none" } }
  base.width = 30
  base.height = 30
  base.padding = 0
  base.margin = 0
  gui_style.tf_fave_toggle_button = base
end

-- Alternating row background for Data Viewer (odd rows)
if not gui_style.data_viewer_row_odd then
  gui_style.data_viewer_row_odd = {
    type = "horizontal_flow_style",
    parent = "horizontal_flow",
    horizontally_stretchable = "on",
    vertically_stretchable = "off",
    padding = 0,
    margin = 0,
    -- Use a subtle vanilla-like background for odd rows
    graphical_set = {
      base = {
        center = {position = {136, 0}, size = 1},
        draw_type = "outer",
        tint = {r=0.92, g=0.92, b=0.92, a=1}
      }
    }
  }
end

