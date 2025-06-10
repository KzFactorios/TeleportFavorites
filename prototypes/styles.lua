--- @diagnostic disable: undefined-global

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

-- Load GUI styles for each major GUI
require("prototypes.styles_fave_bar")
require("prototypes.styles_tag_editor")
require("prototypes.styles_data_viewer")
local Constants = require("constants")
local Enum = require("prototypes.enums.enum")


local Styles = {}
local gui_style = data.raw["gui-style"].default

function Styles.default_inner_glow(tint_value, scale_value)
  return
  {
    position = { 183, 128 },
    corner_size = 8,
    tint = tint_value,
    scale = scale_value,
    draw_type = "inner"
  }
end

function Styles.default_glow(tint_value, scale_value)
  return
  {
    position = { 200, 128 },
    corner_size = 8,
    tint = tint_value,
    scale = scale_value,
    draw_type = "outer"
  }
end

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

if not gui_style.tf_main_gui_flow then
  gui_style.tf_main_gui_flow = {
    type = "vertical_flow_style",
    parent = "vertical_flow",
    top_margin = 0,
    right_margin = 0,
    bottom_margin = 0,
    left_margin = 0,
    top_padding = 0,
    right_padding = 0,
    bottom_padding = 0,
    left_padding = 0,
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

if not gui_style.tf_orange_button then
  gui_style.tf_orange_button = {

    type = "button_style",
    parent = "tool_button",
    default_graphical_set =
    {
      base = { position = { 34, 17 }, corner_size = 8 },
      shadow = Enum.ColorEnum.DEFAULT_DIRT
    },
    hovered_graphical_set =
    {
      base = { position = { 202, 199 }, corner_size = 8 },
      shadow = Enum.ColorEnum.DEFAULT_DIRT,
      glow = Styles.default_glow(Enum.ORANGE_BUTTON_GLOW_COLOR, 0.5)
    },
    clicked_graphical_set =
    {
      base = { position = { 352, 17 }, corner_size = 8 },
      shadow = Enum.ColorEnum.DEFAULT_DIRT
    },
    disabled_graphical_set =
    {
      base = { position = { 368, 17 }, corner_size = 8 },
      shadow = Enum.ColorEnum.DEFAULT_DIRT
    },
    left_click_sound = "__core__/sound/gui-green-confirm.ogg",
  }
end

if not gui_style.tf_frame_title then
  gui_style.tf_frame_title = {
    type = "label_style",
    parent = "frame_title",
    top_margin = -2
  }
end

if not gui_style.tf_titlebar_draggable then
  gui_style.tf_titlebar_draggable = {
    type = "empty_widget_style",
    parent = "draggable_space_header",
    horizontally_stretchable = "on"
  }
end

if not gui_style.tf_frame_action_button then
  gui_style.tf_frame_action_button = {
    type = "button_style",
    parent = "frame_action_button",
  }
end

