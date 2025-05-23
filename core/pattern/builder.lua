---@class Builder
-- Base class for the Builder pattern. Use this to construct complex objects step by step.
-- Extend this class to implement specific building steps and a method to retrieve the final product.

local Builder = {}
Builder.__index = Builder

--- Create a new Builder instance
function Builder:new()
    local obj = setmetatable({}, self)
    -- Initialize builder state here
    return obj
end

--- Example method: Reset the builder to initial state
function Builder:reset()
    -- Override in subclass to reset builder state
    error("Builder:reset() not implemented")
end

--- Example method: Add a part to the product
function Builder:add_part(part)
    -- Override in subclass to add a part
    error("Builder:add_part() not implemented")
end

--- Example method: Retrieve the final product
function Builder:get_result()
    -- Override in subclass to return the built object
    error("Builder:get_result() not implemented")
end

-- Example usage (at end of file):
--[[
local MyBuilder = setmetatable({}, { __index = Builder })
function MyBuilder:reset()
    self.parts = {}
end
function MyBuilder:add_part(part)
    table.insert(self.parts, part)
end
function MyBuilder:get_result()
    return table.concat(self.parts, ", ")
end
local builder = MyBuilder:new()
builder:reset()
builder:add_part("foo")
builder:add_part("bar")
print(builder:get_result()) -- prints "foo, bar"
]]

return Builder
