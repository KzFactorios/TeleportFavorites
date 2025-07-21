local position_utils = require("core.utils.position_utils")
---@diagnostic disable: undefined-global

-- Custom styles for the Teleport History Modal GUI


local gui_style = data.raw["gui-style"].default


gui_style.tf_teleport_history_modal_pin_button = {
    type = "button_style",
    parent = "tf_frame_action_button",
    font_color = { r = 1, g = 1, b = 1, a = 1 },
    right_margin = 8,
}

-- Pin button style for active (pinned) state
gui_style.tf_history_modal_pin_button_active = {
    type = "button_style",
    parent = "tf_frame_action_button",
    width = 24,
    height = 24,
    right_margin = 8,
    padding = -4,
    --icon_scale = 2,
    font_color = { r = 0, g = 0, b = 0, a = 1 },
    default_graphical_set = {
        base = {
            filename = "__core__/graphics/gui-new.png",
            priority = "extra-high-no-scale",
            position = {30,16},
            width = 20,
            height = 20,
            corner_size = 8,
            scale = 1,
        }
    },
}

-- Teleport history item button (normal state)
gui_style.tf_teleport_history_item = {
    type = "button_style",
    parent = "list_box_item",
    horizontally_stretchable = "on",
    horizontal_align = "right",
    padding = 0,
    top_padding = 0,
    bottom_padding = 0,
    right_padding = 4,
    left_padding = 0,
    margin = 0,
    top_margin = 1,
    bottom_margin = 1,
    font = "default-small",
    default_font_color = { r = 0.5, g = 0.81, b = 0.94 }, -- Blue color for current item
    hovered_font_color = { r = 0.5, g = 0.81, b = 0.94 },
    clicked_font_color = { r = 0.5, g = 0.81, b = 0.94 },
    minimal_width = 0,
    height = 20,
}

-- Teleport history item button (current/selected state)
gui_style.tf_teleport_history_item_current = {
    type = "button_style",
    parent = "tf_teleport_history_item",
    font = "default-bold",
    default_font_color = { r = 0.98, g = 0.66, b = 0.22, a = 1 },
    hovered_font_color = { r = 0.98, g = 0.98, b = 0.98, a = 1 },
    clicked_font_color = { r = 0.98, g = 0.98, b = 0.98, a = 1 },
}

-- Flow container for teleport history items (icon + text)
gui_style.tf_teleport_history_flow = {
    type = "horizontal_flow_style",
    parent = "horizontal_flow",
    horizontally_stretchable = "on",
    padding = 1,
    top_padding = 0,
    bottom_padding = 0,
    margin = 0,
    vertical_align = "center",
}

-- Main modal frame style (reusing tag editor pattern)
gui_style.tf_teleport_history_modal_frame = {
    type = "frame_style",
    parent = "slot_window_frame",
    padding = 4,
    horizontally_stretchable = "off",
    vertically_stretchable = "off",
    minimal_width = 350,
    maximal_width = 350,
    minimal_height = 100,
    maximal_height = 500,
}

-- Modal content frame style (reusing tag editor pattern)
gui_style.tf_teleport_history_modal_content = {
    type = "frame_style",
    parent = "inside_deep_frame",
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

-- Date label style for history entries (left-aligned, med-light grey)
gui_style.tf_teleport_history_date_label = {
    type = "label_style",
    parent = "label",
    font = "tf_font_7",
    horizontally_stretchable = "on",
    horizontal_align = "left",
    right_padding = 4,
    font_color = { r = 0.4, g = 0.4, b = 0.4, a = 1 }, -- med-light grey
    width = 110,
}

-- History icon label style (for rich text icon labels)
gui_style.tf_history_icon_label = {
    type = "label_style",
    font = "tf_font_9",
    top_padding = -2,
    left_padding = 40,
    horizontally_stretchable = "off",
    vertically_stretchable = "off",
}
