---@diagnostic disable: undefined-global
-- Custom styles for the Favorites Bar GUI (fave_bar)

local util = require("util")
local gui_style = data.raw["gui-style"].default

-- Slot index label (child of sprite-button): keep color when the button is hovered (avoids dark text on locked slots).
local TF_FAVE_BAR_SLOT_NUMBER_COLOR = { r = 0.98, g = 0.66, b = 0.22, a = 0.9 }

-- Locked slot chrome: dark grey face vs default slots; no extra shadow layer (avoids the light outer “frame”).
-- `base.tint` multiplies the slot texture — tune r/g/b and `a` for lighter/darker grey.
local LOCKED_SLOT_BASE_TINT = { r = 0.34, g = 0.34, b = 0.36, a = 0.72 }

-- add all new styles under this line

gui_style.tf_fave_bar_frame = {
    type = "frame_style",
    parent = "slot_window_frame",
    left_padding = 5,
    right_padding = 6,
}

gui_style.tf_fave_toggle_container = {
    type = "frame_style",
    parent = "quick_bar_inner_panel",
    graphical_set = nil,
    left_border = 0,
    horizontal_align = "center",
    top_padding = 1,
    right_padding = 0,
    bottom_padding = 1,
    left_padding = 0,
    left_margin = 0,
    right_margin = 0,
    bottom_margin = 0,
}

gui_style.tf_fave_slots_row = {
    type = "frame_style",
    parent = "quick_bar_inner_panel",
    vertically_stretchable = "off",
    horizontally_stretchable = "on",
    left_margin = 6, -- left border
    right_margin = 0,
    top_padding = 1,
    right_padding = 4,
    bottom_padding = 1,
    left_padding = 0,
}

gui_style.tf_fave_history_toggle_button = {
    type = "button_style",
    parent = "tf_slot_button",
    padding = 5,
    right_margin = -4,
    left_margin = 0,
}

gui_style.tf_fave_bar_visibility_on = {
    type = "button_style",
    parent = "tf_slot_button",
    padding = 2,
    left_margin = 0,
    right_margin = 0,
}

gui_style.tf_fave_bar_visibility_off = { type = "button_style", parent = "tf_fave_bar_visibility_on" }

gui_style.tf_slot_button_smallfont = {
    type = "button_style",
    parent = "slot_button",
    font = "default-small",
    horizontal_align = "center",
    vertical_align = "bottom",

    top_padding = 2,
    right_padding = 4,
    bottom_padding = 4,
    left_padding = 4,

    top_margin = 0,
    right_margin = -4,
    bottom_margin = 0,
    left_margin = 0,
    size = { 40, 40 }
}

gui_style.tf_slot_button_smallfont_map_pin = {
    type = "button_style",
    parent = "tf_slot_button_smallfont",
    top_padding = 4, 
    right_padding = 8,
    bottom_padding = 8,
    left_padding = 8
}

-- Locked favorites: dark grey tinted face; glow and copied shallow-frame shadow omitted for a tight edge (no halo).
do
  local sb = gui_style.slot_button
  if sb and sb.default_graphical_set then
    local function locked_face()
      local g = util.table.deepcopy(sb.default_graphical_set)
      g.glow = nil
      g.shadow = nil
      if g.base then
        g.base = util.table.deepcopy(g.base)
        g.base.tint = LOCKED_SLOT_BASE_TINT
      end
      return g
    end
    local pressed = locked_face()
    gui_style.tf_slot_button_smallfont_locked = {
      type = "button_style",
      parent = "tf_slot_button_smallfont",
      default_graphical_set = util.table.deepcopy(pressed),
      hovered_graphical_set = util.table.deepcopy(pressed),
      clicked_graphical_set = util.table.deepcopy(pressed),
    }
    pressed = locked_face()
    gui_style.tf_slot_button_smallfont_map_pin_locked = {
      type = "button_style",
      parent = "tf_slot_button_smallfont_map_pin",
      default_graphical_set = util.table.deepcopy(pressed),
      hovered_graphical_set = util.table.deepcopy(pressed),
      clicked_graphical_set = util.table.deepcopy(pressed),
    }
  end
end

-- Child sprite on slot button (after label "n"); lock icon. Size: sprite `tf_fave_slot_lock` scale in data.lua.
-- Use negative padding to nudge toward the corner — margins do not affect layout for this nested image in practice.
gui_style.tf_fave_slot_lock_overlay = {
    type = "image_style",
    parent = "image",
    stretch_image_to_widget_size = false,
    horizontal_align = "left",
    vertical_align = "top",
    top_padding = -3,
    left_padding = -3,
}

gui_style.tf_fave_bar_slot_number = {
    type = "label_style",
    font = "tf_font_8",
    font_color = TF_FAVE_BAR_SLOT_NUMBER_COLOR,
    hovered_font_color = TF_FAVE_BAR_SLOT_NUMBER_COLOR,
    parent_hovered_font_color = TF_FAVE_BAR_SLOT_NUMBER_COLOR,
    clicked_font_color = TF_FAVE_BAR_SLOT_NUMBER_COLOR,
    horizontal_align = "center",
    width = 25,
    top_padding = 19
}

gui_style.tf_fave_bar_slot_wrapper = {
    type = "vertical_flow_style",
    width = 40,
    horizontal_align = "center",
    vertical_spacing = 0,
    top_padding = 0,
    bottom_padding = 0,
}

gui_style.tf_fave_bar_slot_label = {
    type = "label_style",
    font = "tf_font_7",
    font_color = { r = 0.7, g = 0.7, b = 0.7, a = 0.9 },
    horizontal_align = "center",
    width = 40,
    single_line = true,
    top_padding = 0,
    bottom_padding = 0,
}

return true
