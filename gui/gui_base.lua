---@diagnostic disable: undefined-global
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
- GuiBase.create_textbox(parent, name, text, style, icon_selector): Create a text-box with optional icon selector.
- GuiBase.create_hflow(parent, name, style): Create a horizontal flow container.
- GuiBase.create_vflow(parent, name, style): Create a vertical flow container.
- GuiBase.create_draggable(parent, name): Create a draggable space widget.
- GuiBase.create_titlebar(parent, name, close_button_name): Create a draggable titlebar with optional close button.

Each function is annotated with argument and return value details.
--]]
local GuiBase = {}
local Helpers = require("core.utils.helpers_suite")
local Enum = require("prototypes.enums.enum")

--- NOTE: All requires MUST be at the top of the file. Do NOT move requires inside functions to avoid circular dependencies.
--- This is a strict project policy. See notes/architecture.md and coding_standards.md for rationale.
--- gui_base.lua MUST NOT require any control/event modules (e.g., control_fave_bar, control_tag_editor). It is a pure GUI helper module.

--- Factory for creating GUI elements with type and options
--- @param element_type string: The type of GUI element (e.g., 'frame', 'label', 'sprite-button', etc.)
--- @param parent LuaGuiElement: The parent element
--- @param opts table: Table of options (name, caption, direction, style, etc.)
--- @return LuaGuiElement: The created element
function GuiBase.create_element(element_type, parent, opts)
    if (type(parent) ~= "table" and type(parent) ~= "userdata") or type(parent.add) ~= "function" then
        error("GuiBase.create_element: parent is not a valid LuaGuiElement")
    end
    if opts.type then opts.type = nil end --- Prevent accidental overwrite
    local params = { type = element_type }
    for k, v in pairs(opts) do params[k] = v end    -- Defensive: ensure name is a string
    if params.name == nil or type(params.name) ~= "string" or params.name == "" then
        -- Use deterministic naming based on element type and current tick for reproducibility
        local fallback_id = (game and game.tick) or os.time() or 0
        params.name = element_type .. "_unnamed_" .. tostring(fallback_id)
        log("[TF DEBUG] unnamed element for " .. element_type .. " assigned name: " .. params.name)
    end---@diagnostic disable-next-line
    local elem = parent.add(params)
    -- Handle style assignment: if it's a string, we can't assign it directly to elem.style
    -- The style should be set during creation in the params table
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
    local opts = { name = name, caption = caption }
    if style then
        opts.style = style
    end
    local elem = GuiBase.create_element('label', parent, opts)
    return elem
end

--- Create a textfield with optional style.
--- @param parent LuaGuiElement: Parent element
--- @param name string: Name of the textfield
--- @param text? string: Initial text (default: "")
--- @param style? string|nil: Optional style name
--- @return LuaGuiElement: The created textfield
function GuiBase.create_textfield(parent, name, text, style)
    local opts = {
        name = name,
        text = text or "",
        style = style
    }
    -- Remove nil values
    for k, v in pairs(opts) do
        if v == nil then opts[k] = nil end
    end
    return GuiBase.create_element('textfield', parent, opts)
end

--- Create a button with optional style.
--- @param parent LuaGuiElement: Parent element
--- @param name string: Name of the button
--- @param caption LocalisedString|string: Button text
--- @param style? string|nil: Optional style name
--- @return LuaGuiElement: The created button
function GuiBase.create_button(parent, name, caption, style)
    local opts = { name = name, caption = caption }
    if style then
        opts.style = style
    end
    return GuiBase.create_element('button', parent, opts)
end

--- Create a horizontal flow container.
--- @param parent LuaGuiElement: Parent element
--- @param name string: Name of the flow
--- @param style? string|nil: Optional style name
--- @return LuaGuiElement: The created flow
function GuiBase.create_hflow(parent, name, style)
    return GuiBase.create_element('flow', parent, { name = name, direction = 'horizontal', style = style })
end

--- Create a vertical flow container.
--- @param parent LuaGuiElement: Parent element
--- @param name string: Name of the flow
--- @param style? string|nil: Optional style name
--- @return LuaGuiElement: The created flow
function GuiBase.create_vflow(parent, name, style)
    return GuiBase.create_element('flow', parent, { name = name, direction = 'vertical', style = style })
end

--- Create a flow container (shorthand for create_hflow/create_vflow).
--- @param parent LuaGuiElement: Parent element
--- @param name string: Name of the flow
--- @param direction string: 'horizontal' or 'vertical' (default: 'horizontal')
--- @param style? string|nil: Optional style name
--- @return LuaGuiElement: The created flow
function GuiBase.create_flow(parent, name, direction, style)
    return GuiBase.create_element('flow', parent, { 
        name = name, 
        direction = direction or 'horizontal', 
        style = style 
    })
end

--- Create a draggable space
--- @param parent LuaGuiElement: Parent element
--- @param name? string|nil: Name of the flow
function GuiBase.create_draggable(parent, name)
    if type(name) ~= "string" or name == "" then
        name = "draggable_space"
    end
    ---@diagnostic disable-next-line
    local dragger = parent.add { type = "empty-widget", name = name, style = "tf_draggable_space_header" }
    if not dragger or not dragger.valid then
        error("GuiBase.create_draggable: failed to create draggable space")
    end    local drag_target = Helpers.get_gui_frame_by_element(parent) or nil

    -- Set drag target for any screen-based GUI frame (generalized for reusability)
    if drag_target and drag_target.parent and drag_target.parent.name == "screen" then
        dragger.drag_target = drag_target
    end

    return dragger
end

--- Create a draggable titlebar with optional close button.
--- @param parent LuaGuiElement: Parent element
--- @param name? string|nil: name of the titlebar element
--- @param close_button_name? string|nil
--- @return LuaGuiElement, LuaGuiElement, LuaGuiElement: The created titlebar flow
function GuiBase.create_titlebar(parent, name, close_button_name)
    local titlebar = GuiBase.create_element('flow', parent, {
        name = name or "tf_titlebar",
        direction = "horizontal",
        style = "tf_titlebar_flow"
    })

    local title_label = GuiBase.create_label(titlebar, "gui_base_title_label", "", "tf_frame_title")

    local draggable = GuiBase.create_draggable(titlebar, "tf_titlebar_draggable")    local close_button = GuiBase.create_icon_button(titlebar, close_button_name or "titlebar_close_button",
        Enum.SpriteEnum.CLOSE, "",
        "tf_frame_action_button")

    return titlebar, title_label, close_button
end

--- Create an empty-widget element.
--- @param parent LuaGuiElement: Parent element
--- @param name string: Name of the empty-widget
--- @param style? string|nil: Optional style name
--- @return LuaGuiElement: The created empty-widget
function GuiBase.create_empty_widget(parent, name, style)
    local opts = { name = name }
    if style then
        opts.style = style
    end
    return GuiBase.create_element('empty-widget', parent, opts)
end

--- Create a table element.
--- @param parent LuaGuiElement: Parent element
--- @param name string: Name of the table
--- @param column_count? number: Number of columns (default: 1)
--- @param style? string|nil: Optional style name
--- @return LuaGuiElement: The created table
function GuiBase.create_table(parent, name, column_count, style)
    local opts = { 
        name = name, 
        column_count = column_count or 1 
    }
    if style then
        opts.style = style
    end
    return GuiBase.create_element('table', parent, opts)
end

--- Create a text-box with optional icon selector (Factorio 1.1.77+).
--- @param parent LuaGuiElement: Parent element
--- @param name string: Name of the text-box
--- @param text? string: Initial text
--- @param style? string: Optional style name
--- @param icon_selector? boolean: Whether to add the rich text icon selector (default: false)
--- @return LuaGuiElement: The created text-box
function GuiBase.create_textbox(parent, name, text, style, icon_selector)
    local opts = {
        name = name,
        text = text or "",
        style = style,
        icon_selector = icon_selector or false
    }
    -- Remove nil values
    for k, v in pairs(opts) do
        if v == nil then opts[k] = nil end
    end
    return GuiBase.create_element('text-box', parent, opts)
end

return GuiBase
