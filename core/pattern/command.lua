---@class Command
-- Base class for the Command pattern. Use this to encapsulate a request as an object, allowing parameterization and queuing of requests.
-- Extend this class to implement specific commands with an execute method.

local Command = {}
Command.__index = Command

--- Create a new Command instance
function Command:new()
    local obj = setmetatable({}, self)
    return obj
end

--- Execute the command
function Command:execute(...)
    -- Override in subclass to perform the command
    error("Command:execute() not implemented")
end

-- Example usage (at end of file):
--[[
local PrintCommand = setmetatable({}, { __index = Command })
function PrintCommand:execute(msg)
    print(msg)
end
local cmd = PrintCommand:new()
cmd:execute("Hello, world!") -- prints "Hello, world!"
]]

return Command
