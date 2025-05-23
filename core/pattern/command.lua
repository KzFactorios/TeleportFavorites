---@class Command
-- Base class for the Command pattern. Use this to encapsulate a request as an object, allowing parameterization and queuing of requests.
-- Extend this class to implement specific commands with an execute method.

local Command = {}
Command.__index = Command

--- Create a new Command instance
function Command:new(fn)
    local obj = setmetatable({}, self)
    obj.fn = fn
    return obj
end

--- Execute the command
function Command:execute()
    if self.fn then self.fn() end
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
