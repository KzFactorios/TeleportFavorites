-- Minimal Adapter pattern stub for test runner compatibility
local Adapter = {}
Adapter.__index = Adapter
function Adapter:new(adaptee)
  local obj = setmetatable({}, self)
  obj.adaptee = adaptee
  return obj
end
return Adapter
