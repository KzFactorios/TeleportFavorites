---@diagnostic disable: undefined-global

local ErrorHandler = require("core.utils.error_handler")
local Enum = require("prototypes.enums.enum")
local BasicHelpers = require("core.utils.basic_helpers")


local GuiBase = {}


function GuiBase.create_image(parent, name, image_path, style)
    local opts = { name = name, image = image_path }
    if style then
        opts.style = style
    end
    return GuiBase.create_element('image', parent, opts)
end

function GuiBase.create_sprite(parent, name, sprite_path, style)
    local opts = { name = name, sprite = sprite_path }
    if style then
        opts.style = style
    end
    return GuiBase.create_element('sprite', parent, opts)
end

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

function GuiBase.create_sprite_button(parent, name, sprite, tooltip, style, enabled)
    return GuiBase.create_icon_button(parent, name, sprite, tooltip, style, enabled)
end

function GuiBase.create_element(element_type, parent, opts)
    if (type(parent) ~= "table" and type(parent) ~= "userdata") or type(parent.add) ~= "function" then
        error("GuiBase.create_element: parent is not a valid LuaGuiElement")
    end
    if opts.type then opts.type = nil end

    local params = { type = element_type }
    for k, v in pairs(opts) do
        if (k == "visible" or k == "enabled" or k == "modal" or k == "auto_center" or k == "force_auto_center") and v == nil then
            ErrorHandler.warn_log("Nil boolean property detected in GUI element creation", {
                element_type = element_type,
                property = k,
                parent_name = parent.name or "unknown"
            })
        else
            params[k] = v
        end
    end

    if params.name == nil or type(params.name) ~= "string" or params.name == "" then
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

function GuiBase.create_frame(parent, name, direction, style)
    return GuiBase.create_element('frame', parent, {
        name = name,
        direction = direction or 'horizontal',
        style = style or 'inside_shallow_frame_with_padding'
    })
end

function GuiBase.create_label(parent, name, caption, style)
    local opts = { name = name, caption = caption }
    if style then
        opts.style = style
    end

    local elem = GuiBase.create_element("label", parent, opts)
    return elem
end

function GuiBase.create_button(parent, name, caption, style)
    local opts = { name = name, caption = caption }
    if style then
        opts.style = style
    end
    return GuiBase.create_element('button', parent, opts)
end

function GuiBase.create_hflow(parent, name, style)
    return GuiBase.create_element('flow', parent, { name = name, direction = 'horizontal', style = style })
end

function GuiBase.create_vflow(parent, name, style)
    return GuiBase.create_element('flow', parent, { name = name, direction = 'vertical', style = style })
end

function GuiBase.create_flow(parent, name, direction, style)
    return GuiBase.create_element('flow', parent, {
        name = name,
        direction = direction or 'horizontal',
        style = style
    })
end

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

    if drag_target and drag_target.parent and drag_target.parent.name == "screen" then
        dragger.drag_target = drag_target
    end

    return dragger
end

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

function GuiBase.create_textbox(parent, name, text, style, icon_selector)
    local opts = {
        name = name,
        text = text or "",
        style = style,
        icon_selector = icon_selector or false
    }
    for k, v in pairs(opts) do
        if v == nil then opts[k] = nil end
    end
    return GuiBase.create_element('text-box', parent, opts)
end

return GuiBase
