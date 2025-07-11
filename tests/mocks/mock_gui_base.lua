-- tests/mocks/mock_gui_base.lua
-- Minimal mock for gui.gui_base

local mock_gui_base = {}

function mock_gui_base.create_element(element_type, parent, opts)
    if not parent then
        -- For testing, create a basic mock parent if none provided
        parent = {
            add = function(params)
                params = params or {}
                return {
                    type = params.type,
                    name = params.name,
                    caption = params.caption,
                    sprite = params.sprite,
                    tooltip = params.tooltip,
                    style = params.style,
                    direction = params.direction,
                    text = params.text or "",
                    enabled = true,
                    valid = true,
                    parent = parent
                }
            end,
            valid = true
        }
    end
    if not parent.add then
        error("create_element: parent must have an add method")
    end
    opts = opts or {}
    opts.type = element_type
    if not opts.name then
        opts.name = element_type .. "_unnamed_" .. math.random(1000)
    end
    return parent.add(opts)
end

function mock_gui_base.create_frame(parent, name, direction, style)
    return mock_gui_base.create_element("frame", parent, {name = name, direction = direction or "horizontal", style = style})
end

function mock_gui_base.create_icon_button(parent, name, sprite, tooltip, style, enabled)
    local btn = mock_gui_base.create_element("sprite-button", parent, {name = name, sprite = sprite, tooltip = tooltip, style = style})
    btn.enabled = enabled ~= false
    return btn
end

function mock_gui_base.create_sprite_button(parent, name, sprite, tooltip, style)
    return mock_gui_base.create_icon_button(parent, name, sprite, tooltip, style)
end

function mock_gui_base.create_label(parent, name, caption, style)
    return mock_gui_base.create_element("label", parent, {name = name, caption = caption, style = style})
end

function mock_gui_base.create_button(parent, name, caption, style)
    return mock_gui_base.create_element("button", parent, {name = name, caption = caption, style = style})
end

function mock_gui_base.create_hflow(parent, name, style)
    return mock_gui_base.create_element("flow", parent, {name = name, direction = "horizontal", style = style})
end

function mock_gui_base.create_vflow(parent, name, style)
    return mock_gui_base.create_element("flow", parent, {name = name, direction = "vertical", style = style})
end

function mock_gui_base.create_flow(parent, name, direction, style)
    return mock_gui_base.create_element("flow", parent, {name = name, direction = direction or "horizontal", style = style})
end

function mock_gui_base.create_textbox(parent, name, text, style, icon_selector)
    return mock_gui_base.create_element("text-box", parent, {name = name, text = text, style = style, icon_selector = icon_selector})
end

function mock_gui_base.create_named_element(element_type, parent, opts)
    -- Match the real GuiBase behavior more closely
    if not parent or not parent.valid then 
        return nil 
    end
    if not opts or not opts.name then 
        return nil 
    end
    
    -- Use parent.add directly like the real implementation
    local elem = parent.add({
        type = element_type,
        name = opts.name,
        style = opts.style
    })
    
    -- Apply additional properties
    if elem then
        if opts.caption then elem.caption = opts.caption end
        if opts.sprite then elem.sprite = opts.sprite end
        if opts.tooltip then elem.tooltip = opts.tooltip end
    end
    
    return elem
end

function mock_gui_base.create_draggable(parent, name)
    return mock_gui_base.create_element("empty-widget", parent, {name = name or "draggable_space"})
end

function mock_gui_base.create_titlebar(parent, name, close_button_name)
    local titlebar = mock_gui_base.create_element("flow", parent, {name = name or "titlebar", direction = "horizontal"})
    local label = mock_gui_base.create_label(titlebar, "title_label", "")
    local draggable = mock_gui_base.create_draggable(titlebar, "draggable")
    local close_btn = mock_gui_base.create_icon_button(titlebar, close_button_name or "close_button", "close")
    return titlebar, label, close_btn
end

return mock_gui_base
