---@class Composite
-- Base class for the Composite pattern. Use this to treat individual objects and compositions of objects uniformly.
-- Extend this class to implement tree-like structures (e.g., GUI hierarchies).

local Composite = {}
Composite.__index = Composite

--- Create a new Composite instance
function Composite:new()
    local obj = setmetatable({}, self)
    obj.children = {}
    return obj
end

--- Add a child to this composite
function Composite:add(child)
    table.insert(self.children, child)
end

--- Remove a child from this composite
function Composite:remove(child)
    for i, c in ipairs(self.children) do
        if c == child then
            table.remove(self.children, i)
            break
        end
    end
end

--- Operation to perform on this composite and its children
function Composite:operation(...)
    -- Override in subclass to perform an operation
    for _, child in ipairs(self.children) do
        if child.operation then
            child:operation(...)
        end
    end
end

-- Example usage (at end of file):
--[[
local Leaf = setmetatable({}, { __index = Composite })
function Leaf:operation()
    print("Leaf operation")
end
local root = Composite:new()
local leaf1 = Leaf:new()
local leaf2 = Leaf:new()
root:add(leaf1)
root:add(leaf2)
root:operation() -- prints "Leaf operation" twice
]]

return Composite
