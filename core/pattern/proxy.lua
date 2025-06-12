---@class Proxy
-- Base class for the Proxy pattern. Use this to control access to another object.
-- Extend this class to add access control, caching, or logging to the real subject.

local Proxy = {}
Proxy.__index = Proxy

--- Create a new Proxy instance
---@param real_subject table The object to proxy
function Proxy:new(real_subject)
    local obj = setmetatable({}, self)
    obj.real_subject = real_subject
    return obj
end

--- Forward request to real subject - override to add proxy behavior
---@param method_name string The method to call on the real subject
---@param ... any Arguments to pass to the method
---@return any
function Proxy:request(method_name, ...)
    -- Override in subclass to add logging, caching, validation, etc.
    if self.real_subject and self.real_subject[method_name] then
        return self.real_subject[method_name](self.real_subject, ...)
    end
    error("Method '" .. tostring(method_name) .. "' not found on real subject")
end

-- Example usage (at end of file):
--[[
local RealSubject = { do_work = function(self, x) return x + 1 end }
local LoggingProxy = setmetatable({}, { __index = Proxy })
function LoggingProxy:request(method_name, ...)
    print("Calling " .. method_name .. " with args:", ...)
    local result = Proxy.request(self, method_name, ...)
    print("Result:", result)
    return result
end
local proxy = LoggingProxy:new(RealSubject)
proxy:request("do_work", 5) -- prints logging info and returns 6
]]

return Proxy
