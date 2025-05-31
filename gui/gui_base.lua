--[[
Shared GUI builder and utility functions for TeleportFavorites
============================================================
Module: gui/GuiBaselua

Provides reusable helpers for constructing all major GUIs in the mod (favorites bar, tag editor, data viewer).

Features:
- Consistent creation of frames, buttons, labels, textfields, flows, and draggable titlebars.
- Ensures all GUIs use the same style and structure for maintainability and a unified look.
- Simplifies GUI code in feature modules by abstracting common patterns.

API:
- GuiBase.create_frame(parent, name, direction, style): Create a styled frame.
- GuiBase.create_icon_button(parent, name, sprite, tooltip, style, enabled): Create a sprite button with icon and tooltip.
- GuiBase.create_label(parent, name, caption, style): Create a label with optional style.
- GuiBase.create_textfield(parent, name, text, style): Create a textfield with optional style.
- GuiBase.create_hflow(parent, name): Create a horizontal flow container.
- GuiBase.create_vflow(parent, name): Create a vertical flow container.
- GuiBase.create_titlebar(parent, title, close_callback): Create a draggable titlebar with optional close button.

Each function is annotated with argument and return value details.
--]]
local GuiBase = {}
local Constants = require("constants")

-- NOTE: All requires MUST be at the top of the file. Do NOT move requires inside functions to avoid circular dependencies.
-- This is a strict project policy. See notes/architecture.md and coding_standards.md for rationale.
-- gui_base.lua MUST NOT require any control/event modules (e.g., control_fave_bar, control_tag_editor). It is a pure GUI helper module.

--- Factory for creating GUI elements with type and options
-- @param type string: The type of GUI element (e.g., 'frame', 'label', 'sprite-button', etc.)
-- @param parent LuaGuiElement: The parent element
-- @param opts table: Table of options (name, caption, direction, style, etc.)
-- @return LuaGuiElement: The created element
function GuiBase.create_element(type, parent, opts)
    if opts.type then opts.type = nil end -- Prevent accidental overwrite
    local params = { type = type }
    for k, v in pairs(opts) do params[k] = v end
    local elem = parent.add(params)
    if opts.style then elem.style = opts.style end
    return elem
end

--- Create a styled frame.
-- @param parent LuaGuiElement: Parent element
-- @param name string: Name of the frame
-- @param direction string: 'horizontal' or 'vertical' (default: 'horizontal')
-- @param style string: Optional style name (default: 'inside_shallow_frame_with_padding')
-- @return LuaGuiElement: The created frame
function GuiBase.create_frame(parent, name, direction, style)
    return GuiBase.create_element('frame', parent,
        { name = name, direction = direction or 'horizontal', style = style or 'inside_shallow_frame_with_padding' })
end

--- Create a sprite button with icon, tooltip, and style.
-- @param parent LuaGuiElement: Parent element
-- @param name string: Name of the button
-- @param sprite string: Icon sprite path
-- @param tooltip LocalisedString|nil: Tooltip for the button
-- @param style string: Optional style name (default: 'tf_slot_button')
-- @param enabled bool: Optional, default true
-- @return LuaGuiElement: The created button
function GuiBase.create_icon_button(parent, name, sprite, tooltip, style, enabled)
    local btn = GuiBase.create_element('sprite-button', parent,
        { name = name, sprite = sprite, tooltip = tooltip, style = style or 'tf_slot_button' })
    btn.enabled = enabled ~= false
    return btn
end

--- Create a label with optional style.
-- @param parent LuaGuiElement: Parent element
-- @param name string: Name of the label
-- @param caption LocalisedString|string: Label text
-- @param style string: Optional style name
-- @return LuaGuiElement: The created label
function GuiBase.create_label(parent, name, caption, style)
    -- Defensive: do not set .style if style is a button style (Factorio will error)
    local elem = GuiBase.create_element('label', parent, { name = name, caption = caption })
    if style and not (string.find(style, "button")) then
        elem.style = style
    end
    return elem
end

--- Create a textfield with optional style.
-- @param parent LuaGuiElement: Parent element
-- @param name string: Name of the textfield
-- @param text? string: Initial text
-- @param style? string: Optional style name
-- @return LuaGuiElement: The created textfield
function GuiBase.create_textfield(parent, name, text, style)
    return GuiBase.create_element('textfield', parent, { name = name, text = text, style = style })
end

--- Create a horizontal flow container.
-- @param parent LuaGuiElement: Parent element
-- @param name string: Name of the flow
-- @return LuaGuiElement: The created flow
function GuiBase.create_hflow(parent, name)
    return GuiBase.create_element('flow', parent, { name = name, direction = 'horizontal' })
end

--- Create a vertical flow container.
-- @param parent LuaGuiElement: Parent element
-- @param name string: Name of the flow
-- @return LuaGuiElement: The created flow
function GuiBase.create_vflow(parent, name)
    return GuiBase.create_element('flow', parent, { name = name, direction = 'vertical' })
end

--- Create a draggable titlebar with optional close button.
-- @param parent LuaGuiElement: Parent element
-- @param title LocalisedString|string: Title text
-- @param close_button_name string
-- @param debug boolean: Optional, default false. If true, use debug style for draggable space.
-- @return LuaGuiElement: The created titlebar flow
function GuiBase.create_titlebar(parent, title, close_button_name)
    local bar = GuiBase.create_hflow(parent, "titlebar")
    bar.style.vertical_align = "center"
    bar.style.bottom_margin = 4

    GuiBase.create_label(bar, "gui_base_title_label", title, "frame_title")

    local filler = bar.add { type = "empty-widget", style = "draggable_space" }
    filler.style.horizontally_stretchable = true
    filler.style.height = 24 -- vanilla rib lines are only visible at height 24
    filler.style.padding = { 0, 8, 0, 8 }

    GuiBase.create_icon_button(bar, close_button_name, "utility/close", { "gui.close" },
        "frame_action_button")

    return bar
end

return GuiBase
