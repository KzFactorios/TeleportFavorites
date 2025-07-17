---@diagnostic disable: undefined-global
--[[
Custom styles for the Teleport History Modal GUI
]]

-- 'data' is a global provided by Factorio during mod loading
---@diagnostic disable-next-line: undefined-global
local gui_style = data.raw["gui-style"].default

-- Teleport history item button (normal state)
gui_style.tf_teleport_history_item = {
    type = "button_style",
    parent = "list_box_item",
    horizontally_stretchable = "on",
    padding = 0,
    top_padding = 0,
    bottom_padding = 0,
    right_padding = 8,
    left_padding = 0,
    margin = 0,
    top_margin = 1,
    bottom_margin = 1,
    font = "default-small",
    default_font_color = {r = 0.5, g = 0.81, b = 0.94}, -- Blue color for current item
    hovered_font_color = {r = 0.5, g = 0.81, b = 0.94},
    clicked_font_color = {r = 0.5, g = 0.81, b = 0.94},
    minimal_width = 0,
    height = 20,
    horizontal_align = "right",
}

-- Teleport history item button (current/selected state)
gui_style.tf_teleport_history_item_current = {
    type = "button_style",
    parent = "tf_teleport_history_item",
    font = "default-bold",
    default_font_color = { r = 0.98, g = 0.66, b = 0.22, a = 1 },
    hovered_font_color = { r = 0.98, g = 0.66, b = 0.22, a = 1 },
    clicked_font_color = { r = 0.98, g = 0.66, b = 0.22, a = 1 },
}

-- Flow container for teleport history items (icon + text)
gui_style.tf_teleport_history_flow = {
    type = "horizontal_flow_style",
    horizontally_stretchable = "on",
    padding = 1,
    top_padding = 0,
    bottom_padding = 0,
    margin = 0,
    vertical_align = "center",
}

-- Icon sprite for teleport history items
gui_style.tf_teleport_history_icon = {
    type = "image_style",
    size = {16, 16},
    top_margin = 0,
    right_margin = 6,
    left_margin = 6,
}

-- Main modal frame style (reusing tag editor pattern)
gui_style.tf_teleport_history_modal_frame = {
    type = "frame_style",
    parent = "slot_window_frame",
    padding = 4,
    horizontally_stretchable = "off",
    vertically_stretchable = "off",
    minimal_width = 240,
    maximal_width = 300,
    minimal_height = 100,
    maximal_height = 500,
}

-- Modal content frame style (reusing tag editor pattern)
gui_style.tf_teleport_history_modal_content = {
    type = "frame_style", 
    parent = "inside_shallow_frame",
    horizontally_stretchable = "on",
    vertically_stretchable = "off",
    padding = 0,
    margin = 0,
}

-- Modal title label style (reusing existing pattern)
gui_style.tf_teleport_history_modal_title = {
    type = "label_style",
    parent = "label",
    font = "default-bold",
    horizontally_stretchable = "on",
    font_color = { r = 1, g = 1, b = 1, a = 1 },
}

-- Empty history label style
gui_style.tf_teleport_history_empty_label = {
    type = "label_style",
    parent = "label",
    font = "default-small",
    left_padding = 12,
    horizontally_stretchable = "on",
    font_color = { r = 0.7, g = 0.7, b = 0.7, a = 1 },
}
