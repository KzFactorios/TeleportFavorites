---@class Strategy
-- Base class for the Strategy pattern. Use this to define a family of algorithms, encapsulate each one, and make them interchangeable.
-- Extend this class to implement specific strategies and select them at runtime.

local Strategy = {}
Strategy.__index = Strategy

--- Create a new Strategy instance
function Strategy:new()
    local obj = setmetatable({}, self)
    return obj
end

--- Execute the strategy
function Strategy:execute(...)
    -- Override in subclass to provide algorithm
    error("Strategy:execute() not implemented")
end

-- Example usage (at end of file):
--[[
local ConcreteStrategyA = setmetatable({}, { __index = Strategy })
function ConcreteStrategyA:execute(x, y)
    return x + y
end
local ConcreteStrategyB = setmetatable({}, { __index = Strategy })
function ConcreteStrategyB:execute(x, y)
    return x * y
end
local context = { strategy = ConcreteStrategyA:new() }
print(context.strategy:execute(2, 3)) -- 5
context.strategy = ConcreteStrategyB:new()
print(context.strategy:execute(2, 3)) -- 6
]]

return Strategy
