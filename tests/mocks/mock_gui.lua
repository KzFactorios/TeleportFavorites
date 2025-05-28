-- tests/mocks/mock_gui.lua
-- Provides a mock for GUI containers and the patch_add_method utility for test environments

local M = {}

function M.patch_add_method(tbl)
  tbl.children = tbl.children or {}
  tbl.add = function(self, opts)
    local child = opts or {}
    child.children = {}
    if type(self.children) ~= "table" then self.children = {} end
    table.insert(self.children, child)
    if child.name then self[child.name] = child end
    child.add = tbl.add
    -- Add a style table for all GUI elements
    child.style = {}
    return child
  end
end

return M
