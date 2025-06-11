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

-- Math helpers

--- Checks if a number is a whole number (integer)
--- @param n any
--- @return boolean
function basic_helpers.is_whole_number(n)
  if type(n) ~= "number" then return false end
  return n == math.floor(n)
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

--- Ensures that an index is a valid integer (can be negative for coordinates)
--- Rounds floating point numbers to the nearest integer
--- @param index any
--- @return number?
function basic_helpers.normalize_index(index)
  if type(index) == "number" then
    return math.floor(index + 0.5) -- Round to nearest integer
  elseif type(index) == "string" then
    local num = tonumber(index)
    if num then
      return math.floor(num + 0.5) -- Round to nearest integer
    end
  end
  return nil -- Default to nil if invalid
end

return basic_helpers
