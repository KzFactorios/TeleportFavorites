-- core/utils/basic_helpers.lua
-- Minimal, dependency-free helpers for use by other helpers

local basic_helpers = {}

function basic_helpers.pad(n, padlen)
  if type(n) ~= "number" or type(padlen) ~= "number" then return tostring(n or "") end
  local floorn = math.floor(n + 0.5)
  local absn = math.abs(floorn)
  local s = tostring(absn)
  padlen = math.floor(padlen or 3)
  if #s < padlen then s = string.rep("0", padlen - #s) .. s end
  if floorn < 0 then s = "-" .. s end
  return s
end

-- String helpers

--- Trims whitespace from both ends of a string
--- @param s string | any
--- @return string
function basic_helpers.trim(s)
  if type(s) ~= "string" then return "" end
  return s:match("^%s*(.-)%s*$") or ""
end

--- Splits a string into a table of substrings based on a delimiter
--- @param str string | any
--- @param delimiter string | any
--- @return table
function basic_helpers.split_string(str, delimiter)
  if type(str) ~= "string" or type(delimiter) ~= "string" then return {} end
  local result = {}
  for match in str:gmatch("[^" .. delimiter .. "]+") do
    table.insert(result, match)
  end
  return result
end

--- Checks if a string is non-empty
--- @param s any
--- @return boolean
function basic_helpers.is_nonempty_string(s)
  return type(s) == "string" and s ~= "" and s:match("^%s*(.-)%s*$") ~= ""
end

--- Checks if a string value contains a decimal point
--- @param s any
--- @return boolean
function basic_helpers.has_decimal_point(s)
  if type(s) ~= "string" then return false end
  return s:find("%.") ~= nil
end

--- Ensures that an index is a valid positive integer. uint
--- @param index any
--- @return uint?
function basic_helpers.normalize_index(index)
  if type(index) == "number" and index >= 1 and index % 1 == 0 then
    return math.floor(index)
  elseif type(index) == "string" then
    local num = tonumber(index)
    if num and num >= 1 and num % 1 == 0 then
      return math.floor(num)
    end
  end
  return nil -- Default to nil if invalid 
end

return basic_helpers
