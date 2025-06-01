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

--- NOTE: All requires MUST be at the top of the file. Do NOT move requires inside functions to avoid circular dependencies.
--- This is a strict project policy. See notes/architecture.md and coding_standards.md for rationale.
--- gui_base.lua MUST NOT require any control/event modules (e.g., control_fave_bar, control_tag_editor). It is a pure GUI helper module.

--- Factory for creating GUI elements with type and options
--- @param type string: The type of GUI element (e.g., 'frame', 'label', 'sprite-button', etc.)
--- @param parent LuaGuiElement: The parent element
--- @param opts table: Table of options (name, caption, direction, style, etc.)
--- @return LuaGuiElement: The created element
function GuiBase.create_element(element_type, parent, opts)
    if (type(parent) ~= "table" and type(parent) ~= "userdata") or type(parent.add) ~= "function" then
        error("GuiBase.create_element: parent is not a valid LuaGuiElement")
    end
    if opts.type then opts.type = nil end --- Prevent accidental overwrite
    local params = { type = element_type }
    for k, v in pairs(opts) do params[k] = v end
    local elem = parent.add(params)
    if opts.style then elem.style = opts.style end
    return elem
end

--- Create a styled frame.
--- @param parent LuaGuiElement: Parent element
--- @param name string: Name of the frame
--- @param direction string: 'horizontal' or 'vertical' (default: 'horizontal')
--- @param style? string|nil: Optional style name (default: 'inside_shallow_frame_with_padding')
--- @return LuaGuiElement: The created frame
function GuiBase.create_frame(parent, name, direction, style)
    return GuiBase.create_element('frame', parent,
        { name = name, direction = direction or 'horizontal', style = style or 'inside_shallow_frame_with_padding' })
end

--- Create a sprite button with icon, tooltip, and style.
--- @param parent LuaGuiElement: Parent element
--- @param name string: Name of the button
--- @param sprite string: Icon sprite path
--- @param tooltip LocalisedString|nil: Tooltip for the button
--- @param style string: Optional style name (default: 'tf_slot_button')
--- @param enabled? boolean|nil: Optional, default true
--- @return LuaGuiElement: The created button
function GuiBase.create_icon_button(parent, name, sprite, tooltip, style, enabled)
    local btn = GuiBase.create_element('sprite-button', parent,
        { name = name, sprite = sprite, tooltip = tooltip, style = style or 'tf_slot_button' })
    btn.enabled = enabled ~= false
    return btn
end

--- Create a label with optional style.
--- @param parent LuaGuiElement: Parent element
--- @param name string: Name of the label
--- @param caption LocalisedString|string: Label text
--- @param style? string|nil: Optional style name
--- @return LuaGuiElement: The created label
function GuiBase.create_label(parent, name, caption, style)
    local elem = GuiBase.create_element('label', parent, { name = name, caption = caption })
    if style and not (string.find(style, "button")) then
        elem.style = style
    end
    return elem
end

--- Create a textfield with optional style.
--- @param parent LuaGuiElement: Parent element
--- @param name string: Name of the textfield
--- @param text? string: Initial text
--- @param style? string: Optional style name
--- @return LuaGuiElement: The created textfield
function GuiBase.create_textfield(parent, name, text, style)
    return GuiBase.create_element('textfield', parent, { name = name, text = text, style = style })
end

--- Create a horizontal flow container.
--- @param parent LuaGuiElement: Parent element
--- @param name string: Name of the flow
--- @return LuaGuiElement: The created flow
function GuiBase.create_hflow(parent, name)
    return GuiBase.create_element('flow', parent, { name = name, direction = 'horizontal' })
end

--- Create a vertical flow container.
--- @param parent LuaGuiElement: Parent element
--- @param name string: Name of the flow
--- @return LuaGuiElement: The created flow
function GuiBase.create_vflow(parent, name)
    return GuiBase.create_element('flow', parent, { name = name, direction = 'vertical' })
end

--- Create a draggable space 
--- @param parent LuaGuiElement: Parent element
--- @param name string: Name of the flow
--- @param style? string|nil
function GuiBase.create_draggable(parent, name, style)
    local dragger = parent.add{type = "empty-widget", name = name, style = style or "draggable_space" }
    dragger.style.horizontally_stretchable = true
    dragger.style.height = 24 --- vanilla rib lines are only visible at height 24
    dragger.style.padding = { 0, 8, 0, 8 }
end

--- Create a draggable titlebar with optional close button.
--- @param parent LuaGuiElement: Parent element
--- @param name string: name of the titlebar element 
--- @param title LocalisedString|string: Title text
--- @param close_button_name? string|nil
--- @param debug boolean: Optional, default false. If true, use debug style for draggable space.
--- @return LuaGuiElement: The created titlebar flow
function GuiBase.create_titlebar(parent, name, title, close_button_name)
    local titlebar = GuiBase.create_hflow(parent, name or "titlebar")
    titlebar.style.vertical_align = "center"
    titlebar.style.bottom_margin = 4

    local title_label = GuiBase.create_label(titlebar, "gui_base_title_label", title, "frame_title")
    --[[if title_label ~= nil then
        title_label.caption = title
    end
    ]]

    GuiBase.create_draggable(titlebar, "title_bar_draggable")

    GuiBase.create_icon_button(titlebar, close_button_name or "titlebar_close_button", "utility/close", { "tf-gui.close" },
        "frame_action_button")

    return titlebar
end

return GuiBase
