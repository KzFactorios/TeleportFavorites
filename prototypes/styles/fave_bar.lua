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
    top_margin = 0,
    right_margin = 0,
    bottom_margin = 0,
    left_margin = 0,
    vertically_stretchable = "on",
    horizontally_stretchable = "off",
}

gui_style.tf_fave_bar_draggable = {
    type = "empty_widget_style",
    parent = "draggable_space_header",
    horizontally_stretchable = "on",
    width = 16,
    height = 0
}

gui_style.tf_fave_toggle_container = {
    type = "frame_style",
    parent = "inside_deep_frame",     -- match the slots row background
    graphical_set = nil,              -- use parent's background
    padding = 0,
    margin = 0,
    horizontally_stretchable = "off",
    vertically_stretchable = "off"
}

gui_style.tf_fave_toggle_button = {
    type = "button_style",
    parent = "button",
    margin = 0,
    width = 42,
    height = 42,
}

gui_style.tf_fave_slots_row = {
    type = "frame_style",
    parent = "inside_deep_frame",
    vertically_stretchable = "off",
    horizontally_stretchable = "on",
    left_margin = 2,
    padding = 0,
    right_padding = 0,
    left_padding = 5,
    margin = 0
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

    top_margin = 1,
    right_margin = 0,
    bottom_margin = 0,
    left_margin = -4,
    size = { 40, 40 }
}

gui_style.tf_slot_button_smallfont_map_pin = {
    type = "button_style",
    parent = "tf_slot_button_smallfont",
    top_padding = 4,   -- More padding for map pin icon
    right_padding = 8,
    bottom_padding = 8,
    left_padding = 8
}

gui_style.tf_slot_button_locked = {
    type = "button_style",
    parent = "tf_slot_button_smallfont",
    default_graphical_set = {
        base = { position = { 0, 0 }, corner_size = 8, tint = { r = .3, g = .3, b =.3, a = .4 } }
    },
    size = { 40, 40 }
}

gui_style.tf_fave_bar_slot_number = {
    type = "label_style",
    font="technology-slot-level-font",
    font_color = { r = 0.98, g = 0.66, b = 0.22, a = .7 },
    horizontal_align = "center",
    width=25,
    top_padding = 16
}

return true
