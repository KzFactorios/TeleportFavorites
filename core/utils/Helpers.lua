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

return Helpers