---@diagnostic disable: undefined-global

--Centralized GUI style prototypes for TeleportFavorites
-- File: prototypes/styles/init.lua
-- Defines custom GUI styles for use in runtime GUIs, ensuring a consistent, vanilla-aligned look across the mod.
-- Features:
-- Only shared/global styles are defined here.
-- GUI-specific styles are loaded from their respective files.
-- All styles are registered on data.raw["gui-style"].default for use in runtime and control scripts.


require("prototypes.styles.fave_bar")
require("prototypes.styles.tag_editor")
require("prototypes.styles.teleport_history_modal")

local UIEnums = require("prototypes.enums.enum")

local Styles = {}
local gui_style = data.raw["gui-style"].default

local ORANGE_SHADOW = { r = 0.5, g = 0.3, b = 0.1, a = 0.5 }

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

-- (No GUI-specific styles should be defined here. See prototypes/styles/fave_bar.lua, styles/tag_editor.lua)

gui_style.tf_titlebar_flow = {
  type = "horizontal_flow_style",
  parent = "horizontal_flow",
  horizontally_stretchable = "on",
  vertically_stretchable = "off",
  vertical_align = "center",
  top_padding = 0,
  bottom_padding = 0,
  left_padding = 8,
  right_padding = 8,
  left_margin = -8,
  right_margin = -8,
  height = 32,
  horizontal_spacing = 0
}

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

if not gui_style.tf_slot_button then
  local base = {}
  for k, v in pairs(gui_style.slot_button) do
    base[k] = v
  end
  gui_style.tf_slot_button = base
end

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

gui_style.slot_orange_favorite_off = {
  type = "button_style",
  parent = "slot_button",
}

gui_style.slot_orange_favorite_on = {
  type = "button_style",
  parent = "yellow_slot_button",
  width = 40,
  height = 40,
  padding = 1,
  default_graphical_set = {
    base = { position = { 202, 199 }, corner_size = 8 }, 
  },
  hovered_graphical_set = {
    base = { position = { 202, 199 }, corner_size = 8 }, 
    shadow = Styles.rounded_button_glow(ORANGE_SHADOW),
    glow = Styles.default_glow(UIEnums.ColorEnum.ORANGE_BUTTON_GLOW_COLOR, 0.5)
  },
  clicked_graphical_set = {
    base = { position = { 202, 199 }, corner_size = 8, tint = { r = 1, g = 1, b = 1, a = .2 } }, 
    shadow = Styles.rounded_button_glow(UIEnums.ColorEnum.DEFAULT_DIRT_COLOR)
  },
  disabled_graphical_set = {
    -- originally hovered_graphical_set
    base = { position = { 236, 216 }, corner_size = 8 }, 
    shadow = Styles.rounded_button_glow(UIEnums.ColorEnum.DEFAULT_DIRT_COLOR),
  },
}

gui_style.tf_orange_button = {
  type = "button_style",
  parent = "tool_button",
  default_graphical_set =
  {
    base = { position = { 34, 17 }, corner_size = 8 },
    shadow = Styles.rounded_button_glow(ORANGE_SHADOW)
  },
  hovered_graphical_set =
  {
    base = { position = { 202, 199 }, corner_size = 8 },
    shadow = Styles.rounded_button_glow(ORANGE_SHADOW),
    glow = Styles.default_glow({ r = 1, g = 0.5, b = 0, a = 0.5 }, 0.5)
  },
  clicked_graphical_set =
  {
    base = { position = { 352, 17 }, corner_size = 8 },
    shadow = Styles.rounded_button_glow(ORANGE_SHADOW)
  },
  disabled_graphical_set =
  {
    base = { position = { 368, 17 }, corner_size = 8 },
    shadow = Styles.rounded_button_glow(ORANGE_SHADOW)
  }
}

gui_style.tf_frame_title = {
  type = "label_style",
  parent = "frame_title",
  top_margin = -2,
  horizontally_stretchable = "off", 
  minimal_width = 60,               
  single_line = true,               
  horizontal_align = "left",        
  font_color = { r = 1, g = 1, b = 1, a = 1 }
}

gui_style.tf_titlebar_draggable = {
  type = "empty_widget_style",
  parent = "draggable_space_header",
  horizontally_stretchable = "on",
  minimal_width = 8, 
  maximal_width = 9999
}

gui_style.tf_frame_action_button = {
  type = "button_style",
  parent = "frame_action_button",
  right_margin = 0, 
}

-- tf_slot_button_locked is defined in prototypes/styles/fave_bar.lua (loaded before Styles).
-- Add outer glow/shadow here so we can use Styles helpers and UIEnums colors.
do
  local locked = gui_style.tf_slot_button_locked
  if locked then
    local glow_tint = UIEnums.ColorEnum.LOCK_SLOT_GLOW_COLOR
    local shadow_tint = UIEnums.ColorEnum.LOCK_SLOT_SHADOW_COLOR
    local def = locked.default_graphical_set
    local hov = locked.hovered_graphical_set
    local clk = locked.clicked_graphical_set
    if def then
      def.shadow = Styles.rounded_button_glow(shadow_tint)
      def.glow = Styles.default_glow(glow_tint, 0.48)
    end
    if hov then
      hov.shadow = Styles.rounded_button_glow(shadow_tint)
      hov.glow = Styles.default_glow(glow_tint, 0.58)
    end
    if clk then
      clk.shadow = Styles.rounded_button_glow(shadow_tint)
      clk.glow = Styles.default_glow(glow_tint, 0.42)
    end
  end
end
