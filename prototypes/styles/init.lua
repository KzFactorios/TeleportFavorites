--- @diagnostic disable: undefined-global

--[[
Centralized GUI style prototypes for TeleportFavorites
=====================================================
File: prototypes/styles/init.lua

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
require("prototypes.styles.fave_bar")
require("prototypes.styles.tag_editor")
require("prototypes.styles.data_viewer")
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

-- used for textbox and virtual slots (not tab, it is more rounded and uses different style)
function Styles.rounded_button_glow(tint_value)
  return
  {
    position = { 256, 191 },
    corner_size = 16,
    tint = tint_value,
    top_outer_border_shift = 4,
    bottom_outer_border_shift = -4,
    left_outer_border_shift = 4,
    right_outer_border_shift = -4,
    draw_type = "outer"
  }
end

--- Place all shared/global style definitions below this line ---

-- (No GUI-specific styles should be defined here. See prototypes/styles/fave_bar.lua, styles/tag_editor.lua, styles/data_viewer.lua)

if not gui_style.tf_titlebar_flow then
  gui_style.tf_titlebar_flow = {
    type = "horizontal_flow_style",
    parent = "horizontal_flow",
    horizontally_stretchable = "on",
    vertically_stretchable = "off",
    vertical_align = "center",
    top_padding = 0,
    bottom_padding = 0,
    left_padding = 8,  -- Internal padding for content
    right_padding = 8, -- Internal padding for content
    left_margin = -8,  -- Extend into parent's left padding (base: 8px)
    right_margin = -8, -- Extend into parent's right padding (base: 8px)
    height = 32,
    use_header_filler = true,
    horizontal_spacing = 0 -- No spacing between elements to maximize fill
  }
end

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

if not gui_style.slot_orange then
  gui_style.slot_orange = {
    type = "button_style",
    parent = "slot_button",
    default_graphical_set = {
      -- originally default_graphical_set
      base = { position = { 236, 200 }, corner_size = 8 },
      shadow = Styles.rounded_button_glow(Enum.ColorEnum.DEFAULT_DIRT)
    },
    hovered_graphical_set = {
      -- originally hovered_graphical_set
      base = { position = { 236, 216 }, corner_size = 8 }, -- Example hover position
      shadow = Styles.rounded_button_glow(Enum.ColorEnum.DEFAULT_DIRT),
      glow = Styles.default_glow(Enum.ColorEnum.ORANGE_BUTTON_GLOW_COLOR, 0.5)
    },
    clicked_graphical_set = {
      base = { position = { 236, 232 }, corner_size = 8 }, -- Example clicked position
      shadow = Styles.rounded_button_glow(Enum.ColorEnum.DEFAULT_DIRT)
    },
  }
end
if not gui_style.slot_orange_favorite_off then
  gui_style.slot_orange_favorite_off = {
    type = "button_style",
    parent = "slot_button",
  }
end

-- all graphical sets are the same
-- we always want to show the state of is favorite as obnoxious
if not gui_style.slot_orange_favorite_on then
  gui_style.slot_orange_favorite_on = {
    type = "button_style",
    --parent = "slot_orange",
    width = 40,
    height = 40,
    padding = 1,
    --icon_scale = 2, 
    default_graphical_set = {
      -- originally hovered_graphical_set
      base = { position = { 202, 199 }, corner_size = 8 }, -- Example hover position-- 236, 216
      --shadow = Styles.rounded_button_glow(Enum.ColorEnum.DEFAULT_DIRT),
      --glow = Styles.default_glow(Enum.ColorEnum.ORANGE_BUTTON_GLOW_COLOR, 0.5)
    },
    hovered_graphical_set = {
      -- originally hovered_graphical_set
      base = { position = { 202, 199 }, corner_size = 8 }, -- Example hover position
      shadow = Styles.rounded_button_glow(Enum.ColorEnum.DEFAULT_DIRT),
      glow = Styles.default_glow(Enum.ColorEnum.ORANGE_BUTTON_GLOW_COLOR, 0.5)
    },
    clicked_graphical_set = {
      -- originally hovered_graphical_set
      base = { position = { 202, 199 }, corner_size = 8 }, -- Example hover position
      tint = { r = 1, g = 1, b = 1, a = .2 },
      shadow = Styles.rounded_button_glow(Enum.ColorEnum.DEFAULT_DIRT),
      --glow = Styles.default_glow(Enum.ColorEnum.ORANGE_BUTTON_GLOW_COLOR, 0.5)
    },
    disabled_graphical_set = {
      -- originally hovered_graphical_set
      base = { position = { 236, 216 }, corner_size = 8 }, -- Example hover position
      shadow = Styles.rounded_button_glow(Enum.ColorEnum.DEFAULT_DIRT),
      --glow = Styles.default_glow(Enum.ColorEnum.ORANGE_BUTTON_GLOW_COLOR, 0.5)
    },
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
      glow = Styles.default_glow(Enum.ColorEnum.ORANGE_BUTTON_GLOW_COLOR, 0.5)
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
    }
  }
end

if not gui_style.tf_frame_title then
  gui_style.tf_frame_title = {
    type = "label_style",
    parent = "frame_title",
    top_margin = -2,
    horizontally_stretchable = "off", -- Don't stretch, let draggable fill space
    width = 0,                        -- Natural width based on text content
    minimal_width = 60,               -- Minimum space for title text
    natural_width = 0,                -- Let it size naturally to content
    single_line = true,               -- Ensure single line for title
    horizontal_align = "left",        -- Left-align the title text
    font_color = Enum.ColorEnum.CAPTION
  }
end

if not gui_style.tf_titlebar_draggable then
  gui_style.tf_titlebar_draggable = {
    type = "empty_widget_style",
    parent = "draggable_space_header",
    horizontally_stretchable = "on",
    minimal_width = 8,   -- Reduced minimum to allow more expansion
    width = 0,           -- Let it expand naturally
    maximal_width = 9999 -- Allow maximum expansion to fill space
  }
end

if not gui_style.tf_frame_action_button then
  gui_style.tf_frame_action_button = {
    type = "button_style",
    parent = "frame_action_button",
    right_margin = 0, -- Ensure it aligns properly with frame edge
  }
end
