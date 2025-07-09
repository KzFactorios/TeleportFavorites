-- tests/mocks/mock_gui_base.lua
-- Minimal mock for gui.gui_base

local mock_gui_base = {}

function mock_gui_base.create_sprite_button(parent, name, sprite, tooltip, style)
    return parent:add({type = "sprite-button", name = name, tooltip = tooltip, style = style})
end

return mock_gui_base
