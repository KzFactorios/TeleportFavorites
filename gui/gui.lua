-- gui.lua
-- Shared GUI builder and utility functions for TeleportFavorites
-- All major GUIs (favorites bar, tag editor, data viewer) should use these helpers

local gui = {}
local Constants = require("constants")

-- Utility: create a frame with vanilla style
function gui.create_frame(parent, name, direction, style)
    local frame = parent.add{
        type = "frame",
        name = name,
        direction = direction or "horizontal"
    }
    frame.style = style or "inside_shallow_frame_with_padding"
    return frame
end

-- Utility: create a button with icon, tooltip, and style
function gui.create_icon_button(parent, name, sprite, tooltip, style, enabled)
    local btn = parent.add{
        type = "sprite-button",
        name = name,
        sprite = sprite,
        tooltip = tooltip,
        style = style or "tf_slot_button"
    }
    btn.enabled = enabled ~= false
    return btn
end

-- Utility: create a label with optional style
function gui.create_label(parent, name, caption, style)
    local lbl = parent.add{
        type = "label",
        name = name,
        caption = caption
    }
    if style then lbl.style = style end
    return lbl
end

-- Utility: create a textfield
function gui.create_textfield(parent, name, text, style)
    local tf = parent.add{
        type = "textfield",
        name = name,
        text = text or ""
    }
    if style then tf.style = style end
    return tf
end

-- Utility: create a horizontal flow
function gui.create_hflow(parent, name)
    return parent.add{ type = "flow", name = name, direction = "horizontal" }
end

-- Utility: create a vertical flow
function gui.create_vflow(parent, name)
    return parent.add{ type = "flow", name = name, direction = "vertical" }
end

-- Utility: create a draggable titlebar
function gui.create_titlebar(parent, title, close_callback)
    local bar = gui.create_hflow(parent, "titlebar")
    gui.create_label(bar, "title", title, "frame_title")
    local filler = bar.add{ type = "empty-widget", style = "draggable_space_header" }
    filler.style.horizontally_stretchable = true
    if close_callback then
        local close_btn = gui.create_icon_button(bar, "close", "utility/close_white", {"gui.close"}, "frame_action_button")
        close_btn.style.right_margin = 4
        close_btn.onclick = close_callback
    end
    return bar
end

return gui
