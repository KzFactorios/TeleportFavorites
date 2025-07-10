-- tests/mocks/mock_gui_helpers.lua
-- Minimal mock for core.utils.gui_helpers

local function make_mock_element(props)
  local elem = props or {}
  elem.valid = true
  if type(elem.children) ~= "table" then elem.children = {} end
  function elem:add(child_props)
    local child = make_mock_element(child_props)
    if type(self.children) ~= "table" then self.children = {} end
    table.insert(self.children, child)
    if child.name then self[child.name] = child end
    return child
  end
  -- Recursively ensure all children are valid mock elements
  for i, child in ipairs(elem.children) do
    if type(child) ~= "table" or not child.add then
      elem.children[i] = make_mock_element(child)
    end
  end
  return elem
end

local mock_gui_helpers = {}

function mock_gui_helpers.get_or_create_gui_flow_from_gui_top(player)
  return make_mock_element{ name = "main_flow", type = "flow" }
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

-- Add missing stub for create_named_element used by GUI builders
function mock_gui_helpers.create_named_element(parent, def)
    return parent:add(def)
end

return mock_gui_helpers
