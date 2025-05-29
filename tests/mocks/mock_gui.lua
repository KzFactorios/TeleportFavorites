-- tests/mocks/mock_gui.lua
-- Provides a mock for GUI containers and the patch_add_method utility for test environments

local M = {}

function M.patch_add_method(tbl)
  tbl.children = tbl.children or {}
  tbl.visible = true -- Ensure .visible is always present and mutable
  tbl.destroy = function(self)
    if self.parent and type(self.parent.children) == "table" then
      for i = #self.parent.children, 1, -1 do
        if self.parent.children[i] == self then
          table.remove(self.parent.children, i)
          break
        end
      end
    end
    self.children = {}
  end
  tbl.add = function(self, opts)
    local child = opts or {}
    child.name = (opts and opts.name) or child.name
    child.children = child.children or {}
    child.parent = self
    child.visible = true -- Ensure all children have .visible
    if type(child.style) == "string" then
      child.style = { style_name = child.style }
    elseif type(child.style) ~= "table" then
      child.style = {}
    end
    child.style = child.style or {}
    M.patch_add_method(child)
    table.insert(self.children, child)
    if child.name then self[child.name] = child end
    print("[mock_gui] add: parent=", self.name, "added child=", child.name)
    return child
  end
end

function M.mock_frame(opts, parent)
  local t = opts or {}
  t.children = t.children or {}
  t.style = t.style or {}
  t.parent = parent
  M.patch_add_method(t)
  return t
end

M.create_frame = function(parent, name, ...)
  parent.children = parent.children or {}
  local frame = M.mock_frame({name = name}, parent)
  table.insert(parent.children, frame)
  frame.parent = parent
  return frame
end
M.create_hflow = function(parent, name, ...)
  parent.children = parent.children or {}
  local flow = M.mock_frame({name = name}, parent)
  table.insert(parent.children, flow)
  flow.parent = parent
  return flow
end
M.create_label = function(parent, name, ...)
  parent.children = parent.children or {}
  local label = M.mock_frame({name = name}, parent)
  table.insert(parent.children, label)
  label.parent = parent
  return label
end

return M
