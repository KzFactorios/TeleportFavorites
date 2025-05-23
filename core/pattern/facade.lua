---@class Facade
-- Base class for the Facade pattern. Use this to provide a simplified interface to a complex subsystem.
-- Extend this class to wrap multiple subsystems and expose a unified API.

local Facade = {}
Facade.__index = Facade

--- Create a new Facade instance
function Facade:new()
    local obj = setmetatable({}, self)
    -- Initialize subsystems here if needed
    return obj
end

--- Example method: Unified operation
-- Override or extend in your subclass to provide a high-level operation.
function Facade:operation(...)
    -- Should be implemented by subclass
    error("Facade:operation() not implemented")
end

-- Example usage (at end of file):
--[[
local SubsystemA = { doA = function() print("A") end }
local SubsystemB = { doB = function() print("B") end }
local MyFacade = setmetatable({}, { __index = Facade })
function MyFacade:operation()
    SubsystemA.doA()
    SubsystemB.doB()
end
local facade = MyFacade:new()
facade:operation() -- prints "A" then "B"
]]

return Facade
