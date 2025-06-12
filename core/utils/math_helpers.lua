--[[
math_helpers.lua
TeleportFavorites Factorio Mod
-----------------------------
Mathematical utilities: rounding, etc.
Extracted from helpers_suite.lua for better organization and maintainability.
]]

---@class MathHelpers
local MathHelpers = {}

function MathHelpers.math_round(n)
  if type(n) ~= "number" then return 0 end
  local rounded = n >= 0 and math.floor(n + 0.5) or math.ceil(n - 0.5)
  return tostring(rounded) == "-0" and 0 or rounded
end

return MathHelpers
