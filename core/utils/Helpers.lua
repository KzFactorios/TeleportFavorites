local Helpers = {}

--- Deep copy a table (shallow for non-tables)
function Helpers.deep_copy(orig)
  if type(orig) ~= 'table' then return orig end
  local copy = {}
  for k, v in pairs(orig) do
    if type(v) == 'table' then
      copy[k] = Helpers.deep_copy(v)
    else
      copy[k] = v
    end
  end
  return copy
end

--- Pad a number to at least `padlen` digits, preserving minus sign if negative
---@param n number
---@param padlen number
---@return string
function Helpers.pad(n, padlen)
  local floorn = math.floor(n + 0.5)
  local absn = math.abs(floorn)
  local s = tostring(absn)
  padlen = math.floor(padlen or 3)
  if #s < padlen then
    s = string.rep("0", padlen - #s) .. s
  end
  if floorn < 0 then
    s = "-" .. s
  end
  return s
end

return Helpers