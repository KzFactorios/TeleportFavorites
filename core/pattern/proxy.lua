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

-- Minimal Proxy pattern stub for test runner compatibility
function Proxy:new(real)
  local obj = setmetatable({}, self)
  obj.real = real
  return obj
end

return Proxy
