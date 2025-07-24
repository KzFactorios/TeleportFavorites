---@diagnostic disable: undefined-global



require("prototypes.styles.fave_bar")
require("prototypes.styles.tag_editor")
require("prototypes.styles.teleport_history_modal")

local UIEnums = require("prototypes.enums.ui_enums")

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
    shadow = Styles.rounded_button_glow({ r = 0.5, g = 0.3, b = 0.1, a = 0.5 }),
    glow = Styles.default_glow(UIEnums.Colors.ORANGE_BUTTON_GLOW_COLOR, 0.5)
  },
  clicked_graphical_set = {
    base = { position = { 202, 199 }, corner_size = 8, tint = { r = 1, g = 1, b = 1, a = .2 } },
    shadow = Styles.rounded_button_glow(UIEnums.Colors.DEFAULT_DIRT_COLOR)
  },
  disabled_graphical_set = {
    base = { position = { 236, 216 }, corner_size = 8 },
    shadow = Styles.rounded_button_glow(UIEnums.Colors.DEFAULT_DIRT_COLOR),
  },
}

gui_style.tf_orange_button = {
  type = "button_style",
  parent = "tool_button",
  default_graphical_set =
  {
    base = { position = { 34, 17 }, corner_size = 8 },
    shadow = Styles.rounded_button_glow({ r = 0.5, g = 0.3, b = 0.1, a = 0.5 })
  },
  hovered_graphical_set =
  {
    base = { position = { 202, 199 }, corner_size = 8 },
    shadow = Styles.rounded_button_glow({ r = 0.5, g = 0.3, b = 0.1, a = 0.5 }),
    glow = Styles.default_glow({ r = 1, g = 0.5, b = 0, a = 0.5 }, 0.5)
  },
  clicked_graphical_set =
  {
    base = { position = { 352, 17 }, corner_size = 8 },
    shadow = Styles.rounded_button_glow({ r = 0.5, g = 0.3, b = 0.1, a = 0.5 })
  },
  disabled_graphical_set =
  {
    base = { position = { 368, 17 }, corner_size = 8 },
    shadow = Styles.rounded_button_glow({ r = 0.5, g = 0.3, b = 0.1, a = 0.5 })
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
