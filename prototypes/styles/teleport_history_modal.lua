---@diagnostic disable: undefined-global

-- Custom styles for the Teleport History Modal GUI

local gui_style = data.raw["gui-style"].default

-- add all new styles under this line


gui_style.tf_teleport_history_trash_button = {
    type = "button_style",
    parent = "red_button",
    height = 20,
    width = 20,
    padding = 1,
    top_margin = 0,
    right_margin = -4,
    bottom_margin = 0,
    left_margin = 0,
    horizontally_stretchable = "off",
}

gui_style.tf_teleport_history_modal_pin_button = {
    type = "button_style",
    parent = "tf_frame_action_button",
    font_color = { r = 1, g = 1, b = 1, a = 1 },
    right_margin = 8,
    bottom_padding = 2,
    right_padding = 2,
}

gui_style.tf_history_modal_pin_button_active = {
    type = "button_style",
    parent = "tf_frame_action_button",
    width = 24,
    height = 24,
    right_margin = 8,
    padding = -4,
    font_color = { r = 0, g = 0, b = 0, a = 1 },
    default_graphical_set = {
        base = {
            filename = "__core__/graphics/gui-new.png",
            priority = "extra-high-no-scale",
            position = { 30, 16 },
            width = 20,
            height = 20,
            corner_size = 8,
            scale = 1,
        }
    },
}

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
    default_font_color = { r = 0.5, g = 0.81, b = 0.94 },
    hovered_font_color = { r = 0.5, g = 0.81, b = 0.94 },
    clicked_font_color = { r = 0.5, g = 0.81, b = 0.94 },
    minimal_width = 0,
    height = 22,
}

gui_style.tf_teleport_history_item_current = {
    type = "button_style",
    parent = "tf_teleport_history_item",
    font = "default-bold",
    default_font_color = { r = 0.98, g = 0.66, b = 0.22, a = 1 },
    hovered_font_color = { r = 0.98, g = 0.98, b = 0.98, a = 1 },
    clicked_font_color = { r = 0.98, g = 0.98, b = 0.98, a = 1 },
}

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

gui_style.tf_teleport_history_modal_frame = {
    type = "frame_style",
    parent = "slot_window_frame",
    padding = 4,
    top_padding = 0,
    horizontally_stretchable = "off",
    vertically_stretchable = "off",
}

gui_style.tf_teleport_history_modal_content = {
    type = "frame_style",
    parent = "inside_deep_frame",
    horizontally_stretchable = "on",
    vertically_stretchable = "off",
    padding = 0,
    margin = 0,
}

gui_style.tf_teleport_history_modal_title = {
    type = "label_style",
    parent = "label",
    font = "default-bold",
    horizontally_stretchable = "on",
    font_color = { r = 1, g = 1, b = 1, a = 1 },
}

gui_style.tf_teleport_history_empty_label = {
    type = "label_style",
    parent = "label",
    font = "default-small",
    left_padding = 12,
    horizontally_stretchable = "on",
    font_color = { r = 0.7, g = 0.7, b = 0.7, a = 1 },
}

gui_style.tf_teleport_history_date_label = {
    type = "label_style",
    parent = "label",
    font = "tf_font_8",
    horizontally_stretchable = "on",
    horizontal_align = "right",
    right_padding = 4,
    font_color = { r = 0.4, g = 0.4, b = 0.4, a = 1 }, 
    width = 60,
}

gui_style.tf_history_icon_label = {
    type = "label_style",
    font = "tf_font_9",
    top_padding = -2,
    left_padding = 64,
    horizontally_stretchable = "off",
    vertically_stretchable = "off",
}
