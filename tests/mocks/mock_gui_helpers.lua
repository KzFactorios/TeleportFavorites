-- tests/mocks/mock_gui_helpers.lua
-- Minimal mock for core.utils.gui_helpers

local mock_gui_helpers = {}

function mock_gui_helpers.get_or_create_gui_flow_from_gui_top(player)
    -- Return a minimal mock GUI flow with add method
    local flow = {
        children = {},
        valid = true,
        name = "tf_main_gui_flow",
        add = function(self, def)
            local child = {
                type = def.type or "flow",
                name = def.name or "",
                direction = def.direction,
                caption = def.caption,
                tooltip = def.tooltip,
                style = def.style,
                valid = true,
                enabled = true,
                children = {},
                parent = self,
                add = self.add
            }
            table.insert(self.children, child)
            self[child.name] = child
            return child
        end
    }
    return flow
end

function mock_gui_helpers.build_favorite_tooltip()
    return {"tf-gui.fave_slot_tooltip_one", "0,0"}
end

function mock_gui_helpers.create_slot_button(parent, name, icon, tooltip, opts)
    return parent:add({type = "sprite-button", name = name, tooltip = tooltip})
end

function mock_gui_helpers.create_label_with_style(parent, name, caption, style_name)
    return parent:add({type = "label", name = name, caption = caption, style = style_name})
end

return mock_gui_helpers
