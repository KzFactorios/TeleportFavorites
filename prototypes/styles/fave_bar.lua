---@diagnostic disable: undefined-global
--[[
Custom styles for the Favorites Bar GUI (fave_bar)
]]

-- 'data' is a global provided by Factorio during mod loading
---@diagnostic disable-next-line: undefined-global
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
        height = 0
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
            -- orange tint: { r = 0.98, g = 0.66, b = 0.22, a = 1 }
            base = { position = { 34, 17 }, corner_size = 8 }
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

-- Small font button style
if not gui_style.tf_slot_button_smallfont then
    gui_style.tf_slot_button_smallfont = {
        type = "button_style",
        parent = "slot_button",
        font = "default-small",
        horizontal_align = "center",
        vertical_align = "bottom",
        -- font_color = { r = 1, g = 0.647, b = 0, a = 1 }, -- Factorio orange #ffa500
        top_padding = 0,
        bottom_padding = 2,
        size = { 40, 40 }
    }
end

-- Create tinted button variants manually (can't use GuiUtils during data stage)
if not gui_style.tf_slot_button_dragged then
    gui_style.tf_slot_button_dragged = {
        type = "button_style",
        parent = "slot_button",
        default_graphical_set = {
            base = { position = { 0, 0 }, corner_size = 8, tint = { r = 0.2, g = 0.7, b = 1, a = 1 } }
        }
    }
end

if not gui_style.tf_slot_button_locked then
    gui_style.tf_slot_button_locked = {
        type = "button_style", 
        parent = "slot_button",
        default_graphical_set = {
            base = { position = { 0, 0 }, corner_size = 8, tint = { r = 1, g = 0.5, b = 0, a = 1 } }
        }
    }
end

if not gui_style.tf_slot_button_drag_target then
    gui_style.tf_slot_button_drag_target = {
        type = "button_style",
        parent = "slot_button", 
        default_graphical_set = {
            base = { position = { 0, 0 }, corner_size = 8, tint = { r = 1, g = 1, b = 0.2, a = 1 } }
        }
    }
end

return true
