---@diagnostic disable: undefined-global
--[[
Custom styles for the Favorites Bar GUI (fave_bar)
]]

local gui_style = data.raw["gui-style"].default


-- Favorites bar frame (padding: 4, margin: {4, 0, 0, 4})
if not gui_style.tf_fave_bar_frame then
    gui_style.tf_fave_bar_frame = {
        type = "frame_style",
        parent = "slot_window_frame",
        padding = 4,
        top_margin = 0,
        right_margin = 0,
        bottom_margin = 0,
        left_margin = 0,
        vertically_stretchable = "on",
        horizontally_stretchable = "off",
    }
end

if not gui_style.tf_fave_bar_draggable then
    gui_style.tf_fave_bar_draggable = {
        type = "empty_widget_style",
        parent = "draggable_space_header",
        horizontally_stretchable = "on",
        width = 16,
        height = 0,
        maximal_height = 100
    }
end

if not gui_style.tf_fave_toggle_container then
    gui_style.tf_fave_toggle_container = {
        type = "frame_style",
        parent = "inside_deep_frame", -- match the slots row background
        graphical_set = nil,    -- use parent's background
        padding = 2,
        margin = 0,
        horizontally_stretchable = "off",
        vertically_stretchable = "off"
    }
end

if not gui_style.tf_fave_toggle_button then
    gui_style.tf_fave_toggle_button = {
        type = "button_style",
        parent = "tf_slot_button",
        margin = 2,
        width = 40,
        height = 40,
        default_graphical_set = {
            base = { position = { 34, 17 }, corner_size = 8 } --tint = { r = 0.98, g = 0.66, b = 0.22, a = 1 } } -- orange tint
        }
    }
end

if not gui_style.tf_fave_slots_row then
    gui_style.tf_fave_slots_row = {
        type = "frame_style",
        parent = "inside_deep_frame",
        vertically_stretchable = "off",
        horizontally_stretchable = "on",
        left_margin = 0,
        padding = 4,
        margin = 0
    }
end

if not gui_style.tf_slot_button_smallfont then
    local base = {}
    for k, v in pairs(gui_style.slot_button) do base[k] = v end
    base.type = "button_style"
    base.font = "default-small"
    base.horizontal_align = "center"
    base.vertical_align = "bottom"
    base.selected_font_color = nil-- { r = 1, g = 0.647, b = 0, a = 1 }
    base.hovered_font_color = nil--{ r = 1, g = 0.647, b = 0, a = 1 }
    base.clicked_font_color = nil--{ r = 1, g = 0.647, b = 0, a = 1 }
    base.disabled_font_color = nil--{ r = 1, g = 0.647, b = 0, a = 0.5 }
    base.font_color = { r = 1, g = 0.647, b = 0, a = 1 } -- Factorio orange #ffa500
    base.top_padding = 0
    base.bottom_padding = 2
    base.size = { 40, 40 }
    gui_style.tf_slot_button_smallfont = base
end

-- Custom slot button style for drag highlight (blue border)
if not gui_style.tf_slot_button_dragged then
    local base = {}
    for k, v in pairs(gui_style.slot_button) do base[k] = v end
    base.default_graphical_set = {
        base = { position = { 68, 0 }, corner_size = 8, draw_type = "outer", tint = { r = 0.2, g = 0.7, b = 1, a = 1 } }
    }
    base.hovered_graphical_set = {
        base = { position = { 51, 0 }, corner_size = 8, draw_type = "outer", tint = { r = 0.2, g = 0.7, b = 1, a = 1 } }
    }
    base.clicked_graphical_set = {
        base = { position = { 34, 0 }, corner_size = 8, draw_type = "outer", tint = { r = 0.2, g = 0.7, b = 1, a = 1 } }
    }
    base.disabled_graphical_set = {
        base = { position = { 17, 0 }, corner_size = 8, draw_type = "outer", tint = { r = 0.2, g = 0.7, b = 1, a = 0.5 } }
    }
    gui_style.tf_slot_button_dragged = base
end

-- Custom slot button style for locked highlight (orange border)
if not gui_style.tf_slot_button_locked then
    local base = {}
    for k, v in pairs(gui_style.slot_button) do base[k] = v end
    base.default_graphical_set = {
        base = { position = { 68, 0 }, corner_size = 8, draw_type = "outer", tint = { r = 1, g = 0.5, b = 0, a = 1 } }
    }
    base.hovered_graphical_set = {
        base = { position = { 51, 0 }, corner_size = 8, draw_type = "outer", tint = { r = 1, g = 0.5, b = 0, a = 1 } }
    }
    base.clicked_graphical_set = {
        base = { position = { 34, 0 }, corner_size = 8, draw_type = "outer", tint = { r = 1, g = 0.5, b = 0, a = 1 } }
    }
    base.disabled_graphical_set = {
        base = { position = { 17, 0 }, corner_size = 8, draw_type = "outer", tint = { r = 1, g = 0.5, b = 0, a = 0.5 } }
    }
    gui_style.tf_slot_button_locked = base
end

-- Custom slot button style for drag target (yellow border)
if not gui_style.tf_slot_button_drag_target then
    local base = {}
    for k, v in pairs(gui_style.slot_button) do base[k] = v end
    base.default_graphical_set = {
        base = { position = { 68, 0 }, corner_size = 8, draw_type = "outer", tint = { r = 1, g = 1, b = 0.2, a = 1 } }
    }
    base.hovered_graphical_set = {
        base = { position = { 51, 0 }, corner_size = 8, draw_type = "outer", tint = { r = 1, g = 1, b = 0.2, a = 1 } }
    }
    base.clicked_graphical_set = {
        base = { position = { 34, 0 }, corner_size = 8, draw_type = "outer", tint = { r = 1, g = 1, b = 0.2, a = 1 } }
    }
    base.disabled_graphical_set = {
        base = { position = { 17, 0 }, corner_size = 8, draw_type = "outer", tint = { r = 1, g = 1, b = 0.2, a = 0.5 } }
    }
    gui_style.tf_slot_button_drag_target = base
end

return true
