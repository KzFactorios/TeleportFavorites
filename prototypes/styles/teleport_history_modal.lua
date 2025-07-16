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
    padding = 2,
    margin = 0,
    font = "default-small",
    font_color = {r = 1, g = 1, b = 1},
    minimal_width = 0,
    minimal_height = 16,
    horizontal_align = "right",
    rich_text_setting = "enabled",
    right_margin = 12,
}

-- Teleport history item button (current/selected state)
gui_style.tf_teleport_history_item_current = {
    type = "button_style",
    parent = "tf_teleport_history_item",
    default_font_color = {r = 0.5, g = 0.81, b = 0.94}, -- Blue color for current item
    hovered_font_color = {r = 0.5, g = 0.81, b = 0.94},
    clicked_font_color = {r = 0.5, g = 0.81, b = 0.94},
}

-- Flow container for teleport history items (icon + text)
gui_style.tf_teleport_history_flow = {
    type = "horizontal_flow_style",
    horizontally_stretchable = "on",
    padding = 2,
    margin = 1,
    vertical_align = "center",
}

-- Icon sprite for teleport history items
gui_style.tf_teleport_history_icon = {
    type = "image_style",
    size = {16, 16},
    top_margin = 0,
    right_margin = 6,
    left_margin = 2,
}

-- Main modal frame style (reusing tag editor pattern)
gui_style.tf_teleport_history_modal_frame = {
    type = "frame_style",
    parent = "slot_window_frame",
    padding = 4,
    horizontally_stretchable = "on",
    vertically_stretchable = "on",
    minimal_width = 300,
    minimal_height = 400,
    maximal_height = 800,
}

-- Modal content frame style (reusing tag editor pattern)
gui_style.tf_teleport_history_modal_content = {
    type = "frame_style", 
    parent = "inside_shallow_frame",
    horizontally_stretchable = "on",
    vertically_stretchable = "on",
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
