---@diagnostic disable: undefined-global


--[[
Centralized GUI style prototypes for TeleportFavorites
=====================================================
File: prototypes/styles.lua

Defines custom GUI styles for use in runtime GUIs, ensuring a consistent, vanilla-aligned look across the mod.

Features:
- Only shared/global styles are defined here.
- GUI-specific styles are loaded from their respective files.
- All styles are registered on data.raw["gui-style"].default for use in runtime and control scripts.

Usage:
- Reference shared styles by name in runtime GUI code.
- Ensures maintainability and a native Factorio look for all custom GUIs.



tool_button: Light grey, black icon
tool_button_red: Light red, black icon
tool_button_green: Dark green, white icon
tool_button_blue: Dark blue, white icon

subheader_caption_label: If your label is the leftmost element in the subheader frame, use this style
caption_label: Use this style for any other labels in the subheader

--]]

local Constants = require("constants")
local util = require("util")

-- Load GUI styles for each major GUI
require("prototypes.styles_fave_bar")
require("prototypes.styles_tag_editor")
require("prototypes.styles_data_viewer")

local gui_color =
{
  white = { 1, 1, 1 },
  white_with_alpha = { 1, 1, 1, 0.5 },
  grey = { 0.5, 0.5, 0.5 },
  green = { 0, 1, 0 },
  red = { 255, 142, 142 },
  orange = { 0.98, 0.66, 0.22 },
  light_orange = { 1, 0.74, 0.40 },
  caption = { 255, 230, 192 },
  achievement_green = { 210, 253, 145 },
  achievement_tan = { 255, 230, 192 },
  achievement_failed = { 176, 171, 171 },
  achievement_failed_body = { 255, 136, 136 },
  default_dirt_color = { 15, 7, 3, 100 },
  blue = { 128, 206, 240 },
  black_icon = {29,29,29},
  white_icon = {227,227,227}
}

---@diagnostic disable-next-line: undefined-global
local gui_style = data.raw["gui-style"].default

--- Place all shared/global style definitions below this line ---

-- (No GUI-specific styles should be defined here. See prototypes/styles_fave_bar.lua, styles_tag_editor.lua, styles_data_viewer.lua)

if not gui_style.frame_titlebar_flow then
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
end

-- Dark background frame for tag editor content (mimics vanilla tag dialog)
if not gui_style.dark_frame then
  gui_style.dark_frame = {
    type = "frame_style",
    parent = "frame",
    graphical_set = {
      base = { position = { 136, 0 }, corner_size = 8, draw_type = "outer", tint = { r = 0.13, g = 0.13, b = 0.13, a = 1 } },
    },
    padding = 8,
    top_padding = 8,
    bottom_padding = 8,
    left_padding = 8,
    right_padding = 8,
    horizontally_stretchable = "on",
    vertically_stretchable = "off",
    use_header_filler = false
  }
end

if not gui_style.tf_main_gui_flow then
  gui_style.tf_main_gui_flow = {
    type = "vertical_flow_style",
    parent = "vertical_flow",
    top_margin = 2,
    right_margin = 0,
    bottom_margin = 0,
    left_margin = 2
  }
end

-- Custom slot button style for all TeleportFavorites GUIs
if not gui_style.tf_slot_button then
  local base = {}
  for k, v in pairs(gui_style.slot_button) do base[k] = v end
  base.width = 30
  base.height = 30
  gui_style.tf_slot_button = base
end

if not gui_style.tf_draggable_space_header then
  gui_style.tf_draggable_space_header = {
    type                     = "empty_widget_style",
    parent                   = "draggable_space_header",
    minimal_width            = 8,
    height                   = 24,
    horizontally_stretchable = "on",
    top_margin               = 0,
    right_margin             = 8,
    bottom_margin            = 0,
    left_margin              = 8
  }
end

