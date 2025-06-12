---@class Adapter
-- Base class for the Adapter pattern. Use this to convert one interface to another.
-- Extend this class to adapt incompatible interfaces and provide consistent API.

local Adapter = {}
Adapter.__index = Adapter

--- Create a new Adapter instance
---@param adaptee table The object to adapt
function Adapter:new(adaptee)
  local obj = setmetatable({}, self)
  obj.adaptee = adaptee
  return obj
end

--- Perform adapted request - override in subclass
---@param ... any Arguments to pass to adapted method
---@return any
function Adapter:request(...)
  -- Override in subclass to provide adaptation logic
  error("Adapter:request() not implemented")
end

-- Example usage (at end of file):
--[[
local OldAPI = { old_method = function(self, x) return x * 2 end }
local MyAdapter = setmetatable({}, { __index = Adapter })
function MyAdapter:request(value)
  return self.adaptee:old_method(value)
end
local adapter = MyAdapter:new(OldAPI)
print(adapter:request(5)) -- prints 10
]]

return Adapter
