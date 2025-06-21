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
    horizontal_spacing = 0,
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
    width = 40,
    height = 40,
    top_padding = 0,
    right_padding = 0,
    botoom_padding = 0,
    left_padding = 0
    --default_graphical_set = { base = { position = { 34, 17 }, corner_size = 8 } }
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
    font_color = { r = 1, g = 0.647, b = 0, a = 1 },     -- Factorio orange #ffa500

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

-- Create tinted button variants manually (can't use GuiUtils during data stage)
gui_style.tf_slot_button_dragged = {
    type = "button_style",
    parent = "slot_button",
    default_graphical_set = {
        base = { position = { 0, 0 }, corner_size = 8, tint = { r = 0.2, g = 0.7, b = 1, a = 1 } }
    }
}

gui_style.tf_slot_button_locked = {
    type = "button_style",
    parent = "slot_button",
    default_graphical_set = {
        base = { position = { 0, 0 }, corner_size = 8, tint = { r = 1, g = 0.5, b = 0, a = 1 } }
    }
}

gui_style.tf_slot_button_drag_target = {
    type = "button_style",
    parent = "slot_button",
    default_graphical_set = {
        base = { position = { 0, 0 }, corner_size = 8, tint = { r = 1, g = 1, b = 0.2, a = 1 } }
    }
}


return true
