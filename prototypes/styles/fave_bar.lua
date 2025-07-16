---@diagnostic disable: undefined-global
--[[
Custom styles for the Favorites Bar GUI (fave_bar)
]]

-- 'data' is a global provided by Factorio during mod loading
---@diagnostic disable-next-line: undefined-global
local gui_style = data.raw["gui-style"].default


-- Favorites bar frame (padding: 4, margin: {4, 0, 0, 4})
gui_style.tf_fave_bar_frame = {
    type = "frame_style",
    parent = "slot_window_frame",
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
    parent = "quick_bar_inner_panel", --"inside_deep_frame", -- match the slots row background
    graphical_set = nil,              -- use parent's background
    padding = 0,
    top_padding = 0,
    bottom_padding = 4,
    margin = 0,
    bottom_margin = -1,
    horizontally_stretchable = "off",
    vertically_stretchable = "off",
    vertical_align = "top",
    width = 60,
    height = 40,
}

gui_style.tf_fave_toggle_flow = {
    type = "horizontal_flow_style",
    horizontal_align = "center",
    padding = 0,
    margin = 0,
    top_margin = 1,
    bottom_margin = 0,
    top_padding = 0,
    bottom_padding = 0,
    horizontally_stretchable = "on",
    vertically_stretchable = "on",
    }
    
    gui_style.tf_fave_bar_visibility_on = {
    type = "button_style",
    parent = "slot_button",
    margin = 0,
    top_margin = 0,
    bottom_margin = 0,
    width = 60,
    height = 16,
    padding = 0,
}

gui_style.tf_fave_bar_visibility_off = {
    type = "button_style",
    parent = "slot_button",
    margin = 0,
    top_margin = 0,
    bottom_margin = 0,
    width = 60,
    height = 16,
    padding = 0,
}

gui_style.fave_bar_teleport_history_label_style = {
    type = "label_style",
    --parent = "default_label",
    font = "tf_font_8",
    font_color = { r = 0.98, g = 0.66, b = 0.22, a = 1 },
    horizontal_align = "center",
    width = 60,
    height = 9,
    padding = 0,
    top_margin = 0,
    bottom_margin = 0,
}

gui_style.fave_bar_coords_label_style = {
    type = "label_style",
    --parent = "default_label",
    font = "tf_font_8",
    font_color = { r = 0.98, g = 0.66, b = 0.22, a = 1 },
    horizontal_align = "center",
    width = 60,
    height = 9,
    padding = 0,
    top_margin = 1,
    bottom_margin = 0,
}

gui_style.tf_fave_slots_row = {
    type = "frame_style",
    parent = "quick_bar_inner_panel",
    --parent = "slot_button_deep_frame",
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
    top_padding = 4, -- More padding for map pin icon
    right_padding = 8,
    bottom_padding = 8,
    left_padding = 8
}

gui_style.tf_slot_button_locked = {
    type = "button_style",
    --parent = "tf_slot_button_smallfont",
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

gui_style.tf_fave_history_container = {
    type = "frame_style",
    parent = "quick_bar_inner_panel",
    graphical_set = nil,
    padding = 0,
    margin = 0,
    horizontally_stretchable = "off",
    vertically_stretchable = "off",
    vertical_align = "top",
    width = 40,
    height = 40,
}

gui_style.tf_fave_history_toggle_button = {
    type = "button_style",
    parent = "tf_slot_button",
    padding = 8
}

return true
