---@diagnostic disable: undefined-global
-- Custom styles for the Favorites Bar GUI (fave_bar)

local gui_style = data.raw["gui-style"].default

-- add all new styles under this line

gui_style.tf_fave_bar_frame = {
    type = "frame_style",
    padding = 3,
    left_padding = 4,
    right_padding = 4,
    top_margin = 0,
    right_margin = 0,
    bottom_margin = 0,
    left_margin = 0,
    vertically_stretchable = "on",
    horizontally_stretchable = "off",
}

gui_style.tf_fave_toggle_container = {
    type = "frame_style",
    parent = "quick_bar_inner_panel",
    graphical_set = nil,
    left_border = 0,
    horizontal_align = "center",
    left_padding = 0,
    right_padding = 0,
    left_margin = 0,
    right_margin = 0,
}

gui_style.tf_fave_history_toggle_button = {
    type = "button_style",
    parent = "tf_slot_button",
    padding = 0,
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

gui_style.tf_fave_bar_visibility_off = {
    type = "button_style",
    parent = "tf_slot_button",
    padding = 2,
    left_margin = 0,
    right_margin = 0,
}

gui_style.tf_fave_slots_row = {
    type = "frame_style",
    parent = "quick_bar_inner_panel",
    vertically_stretchable = "off",
    horizontally_stretchable = "on",
    left_margin = 5,
    right_margin = 0,
    padding = 0,
    right_padding = 4,
    left_padding = 0,
}

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

gui_style.tf_slot_button_locked = {
    type = "button_style",
    parent = "slot_button_in_shallow_frame",
    default_graphical_set = {
        base = { position = { 0, 0 }, corner_size = 8, tint = { r = .3, g = .3, b = .3, a = .4 } }
    },
    size = { 40, 40 },
    top_padding = 1,
    right_padding = 4,
    bottom_padding = 4,
    left_padding = 4,
    top_margin = 0,
    right_margin = 0,
    bottom_margin = 0,
    left_margin = 0
}

gui_style.tf_fave_bar_slot_number = {
    type = "label_style",
    font = "tf_font_8",
    font_color = { r = 0.98, g = 0.66, b = 0.22, a = 1 },
    horizontal_align = "center",
    width = 25,
    top_padding = 18
}

gui_style.tf_fave_bar_locked_slot_number = {
    type = "label_style",
    parent = "tf_fave_bar_slot_number",
    top_padding = 20
}

gui_style.tf_fave_bar_slot_lock_sprite = {
    type = "image_style",
    top_padding = -3,
    left_padding = -5
}

return true
