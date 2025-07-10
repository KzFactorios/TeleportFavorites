-- tests/mocks/mock_gui_validation.lua
-- Minimal mock for core.utils.gui_validation

local mock_gui_validation = {}

function mock_gui_validation.find_child_by_name(parent, name)
    if not parent or not parent.children then return nil end
    for _, child in ipairs(parent.children) do
        if child.name == name then return child end
        -- Recursively search children
        local found = mock_gui_validation.find_child_by_name(child, name)
        if found then return found end
    end
    -- Also check direct property for test convenience
    if parent[name] and parent[name].valid then return parent[name] end
    return nil
end

function mock_gui_validation.apply_style_properties(element, style_overrides)
    -- No-op for tests
    return element
end

return mock_gui_validation
