---@class Proxy
-- Base class for the Proxy pattern. Use this to control access to another object.
-- Extend this class to add access control, caching, or logging to the real subject.

local Proxy = {}
Proxy.__index = Proxy

--- Create a new Proxy instance
-- @param real_subject The object to proxy
function Proxy:new(real_subject)
    local obj = setmetatable({}, self)
    obj.real_subject = real_subject
    return obj
end

--- Example method: Forwarded request
-- Override or extend in your subclass to add logic before/after forwarding.
function Proxy:request(...)
    -- Should be implemented by subclass
    error("Proxy:request() not implemented")
end

-- Example usage (at end of file):
--[[
local RealSubject = { request = function() print("RealSubject:request() called") end }
local MyProxy = setmetatable({}, { __index = Proxy })
function MyProxy:request()
    print("Proxy: Pre-processing")
    self.real_subject:request()
    print("Proxy: Post-processing")
end
local real = setmetatable({}, { __index = RealSubject })
local proxy = MyProxy:new(real)
proxy:request() -- prints pre, real, post
]]

return Proxy
