---@diagnostic disable: undefined-global

-- TeleportFavorites GUI Base Module
-- Provides reusable builder functions for all major GUI elements in the mod.
-- Ensures consistent style, structure, and maintainability across GUIs.
--
-- Main Features:
--   - Frame, button, label, text-box, flow (horizontal/vertical), draggable space, titlebar
--   - Defensive argument handling and style defaults
--   - All functions are top-level and annotated
--
-- Element Builder Hierarchy:
--
--   GuiBase
--   ├── create_frame(parent, name, direction, style)
--   ├── create_button(parent, name, caption, style)
--   ├── create_label(parent, name, caption, style)
--   ├── create_sprite_button(parent, name, sprite, tooltip, style, enabled)
--   ├── create_element(element_type, parent, opts)
--   ├── create_hflow(parent, name, style)
--   ├── create_vflow(parent, name, style)
--   ├── create_flow(parent, name, direction, style)
--   ├── create_draggable(parent, name)
--   ├── create_titlebar(parent, name, close_button_name)
--   └── create_textbox(parent, name, text, style, icon_selector)


local ErrorHandler = require("core.utils.error_handler")
local Enum = require("prototypes.enums.enum")
local BasicHelpers = require("core.utils.basic_helpers")


local GuiBase = {}


--- Create an image element with optional style.
--- @param parent LuaGuiElement: Parent element
--- @param name string: Name of the image element
--- @param image_path string: Image or sprite path (e.g., 'item/iron-plate')
--- @param style? string|nil: Optional style name
--- @return LuaGuiElement: The created image element
function GuiBase.create_image(parent, name, image_path, style)
    local opts = { name = name, image = image_path }
    if style then
        opts.style = style
    end
    return GuiBase.create_element('image', parent, opts)
end

--- Create a sprite element with optional style.
--- @param parent LuaGuiElement: Parent element
--- @param name string: Name of the sprite element
--- @param sprite_path string: Sprite path (e.g., 'item/iron-plate')
--- @param style? string|nil: Optional style name
--- @return LuaGuiElement: The created sprite element
function GuiBase.create_sprite(parent, name, sprite_path, style)
    local opts = { name = name, sprite = sprite_path }
    if style then
        opts.style = style
    end
    return GuiBase.create_element('sprite', parent, opts)
end

--- Create an icon (sprite) button with tooltip and style.
--- @param parent LuaGuiElement: Parent element
--- @param name string: Name of the button
--- @param sprite string: Icon sprite path
--- @param tooltip LocalisedString|string|nil: Tooltip for the button
--- @param style string|nil: Optional style name (default: 'tf_slot_button')
--- @param enabled boolean|nil: Optional, default true
--- @return LuaGuiElement: The created button
function GuiBase.create_icon_button(parent, name, sprite, tooltip, style, enabled)
    local opts = {
        name = name,
        sprite = sprite,
        style = style or 'tf_slot_button',
        enabled = enabled == nil and true or enabled
    }
    local button = GuiBase.create_element('sprite-button', parent, opts)
    if tooltip then
        button.tooltip = tooltip
    end
    return button
end

--- Local helper function to find frame containing element (avoids circular dependency with GuiUtils)
--- @param element LuaGuiElement Starting element
--- @return LuaGuiElement? frame Found frame or nil
local function get_gui_frame_by_element(element)
    if not BasicHelpers.is_valid_element(element) then return nil end

    local current ---@type LuaGuiElement?  -- allow nil
    current = element
    while current and current.valid do
        if current.type == "frame" then
            return current
        end
        current = current.parent
    end
    return nil
end

--- Create a sprite button with icon, tooltip, and style.
--- @param parent LuaGuiElement: Parent element
--- @param name string: Name of the button
--- @param sprite string: Icon sprite path
--- @param tooltip LocalisedString|string|nil: Tooltip for the button
--- @param style string: Optional style name (default: 'tf_slot_button')
--- @param enabled? boolean|nil: Optional, default true
--- @return LuaGuiElement: The created button
function GuiBase.create_sprite_button(parent, name, sprite, tooltip, style, enabled)
    return GuiBase.create_icon_button(parent, name, sprite, tooltip, style, enabled)
end

--- Factory for creating GUI elements with type and options
--- @param element_type string: The type of GUI element (e.g., 'frame', 'label', 'sprite-button', etc.)
--- @param parent LuaGuiElement: The parent element
--- @param opts table: Table of options (name, caption, direction, style, etc.)
--- @return LuaGuiElement: The created element
function GuiBase.create_element(element_type, parent, opts)
    if (type(parent) ~= "table" and type(parent) ~= "userdata") or type(parent.add) ~= "function" then
        error("GuiBase.create_element: parent is not a valid LuaGuiElement")
    end
    if opts.type then opts.type = nil end -- Prevent accidental overwrite

    local params = { type = element_type }
    for k, v in pairs(opts) do
        -- Check for nil boolean properties that could cause "bool expected, got nil" errors
        if (k == "visible" or k == "enabled" or k == "modal" or k == "auto_center" or k == "force_auto_center") and v == nil then
            ErrorHandler.warn_log("Nil boolean property detected in GUI element creation", {
                element_type = element_type,
                property = k,
                parent_name = parent.name or "unknown"
            })
            -- Skip adding nil boolean properties to prevent Factorio API errors
        else
            params[k] = v
        end
    end

    -- Defensive: ensure name is a string
    if params.name == nil or type(params.name) ~= "string" or params.name == "" then
        -- Use deterministic naming based on element type and current tick for reproducibility
        local fallback_id = (game and game.tick) or os.time() or 0
        params.name = element_type .. "_unnamed_" .. tostring(fallback_id)
        ErrorHandler.debug_log("Unnamed element assigned name", {
            element_type = element_type,
            assigned_name = params.name
        })
    end

    ---@diagnostic disable-next-line
    local elem = parent.add(params)
    return elem
end

--- @return LuaGuiElement: The created frame
function GuiBase.create_frame(parent, name, direction, style)
    return GuiBase.create_element('frame', parent, {
        name = name,
        direction = direction or 'horizontal',
        style = style or 'inside_shallow_frame_with_padding'
    })
end

--- @param caption LocalisedString|string: Label text
--- @param style? string|nil: Optional style name
--- @return LuaGuiElement: The created label
function GuiBase.create_label(parent, name, caption, style)
    local opts = { name = name, caption = caption }
    if style then
        opts.style = style
    end

    local elem = GuiBase.create_element("label", parent, opts)
    return elem
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
    end

    local drag_target = get_gui_frame_by_element(parent) or nil

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

    local draggable = GuiBase.create_draggable(titlebar, "tf_titlebar_draggable")
    local close_button = GuiBase.create_icon_button(titlebar, close_button_name or "titlebar_close_button",
        Enum.SpriteEnum.CLOSE, nil, "tf_frame_action_button")

    return titlebar, title_label, close_button
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
