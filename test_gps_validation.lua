-- Test script for enhanced GPS core validation
-- Run with: lua test_gps_validation.lua

-- Mock dependencies
local basic_helpers = {
  pad = function(n, padlen)
    if type(n) ~= "number" or type(padlen) ~= "number" then return tostring(n or "") end
    local floorn = math.floor(n + 0.5)
    local absn = math.abs(floorn)
    local s = tostring(absn)
    padlen = math.floor(padlen or 3)
    if #s < padlen then s = string.rep("0", padlen - #s) .. s end
    if floorn < 0 then s = "-" .. s end
    return s
  end,
  trim = function(s) return type(s) == "string" and s:match("^%s*(.-)%s*$") or "" end
}

local GPSParser = {
  parse_gps_string = function(gps)
    if type(gps) ~= "string" then return nil end
    local x, y, s = gps:match("^(%-?%d+)%.(%-?%d+)%.(%d+)$")
    if not x or not y or not s then return nil end
    return {
      x = tonumber(x),
      y = tonumber(y),
      s = tonumber(s)
    }
  end
}

local padlen = 3
local BLANK_GPS = "1000000.1000000.1"

-- Test function (simplified version)
local function coords_string_from_map_position(map_position)
  -- Validate input parameter type
  if type(map_position) ~= "table" then 
    return "" 
  end
  
  local x, y = map_position.x, map_position.y
  
  -- Validate coordinates are numbers
  if type(x) ~= "number" or type(y) ~= "number" then 
    return "" 
  end
  
  return basic_helpers.pad(x, padlen) .. "." .. basic_helpers.pad(y, padlen)
end

-- Test cases
local test_cases = {
  -- Valid cases
  {input = {x = 123, y = 456}, expected = "123.456", desc = "Positive coordinates"},
  {input = {x = -5, y = 10}, expected = "-005.010", desc = "Mixed positive/negative"},
  {input = {x = 0, y = 0}, expected = "000.000", desc = "Zero coordinates"},
  {input = {x = 1000, y = -2000}, expected = "1000.-2000", desc = "Large coordinates"},
  
  -- Invalid cases (should return empty string)
  {input = nil, expected = "", desc = "Nil input"},
  {input = "not a table", expected = "", desc = "String input"},
  {input = 123, expected = "", desc = "Number input"},
  {input = {}, expected = "", desc = "Empty table"},
  {input = {x = "123", y = 456}, expected = "", desc = "String x coordinate"},
  {input = {x = 123, y = "456"}, expected = "", desc = "String y coordinate"},
  {input = {x = nil, y = 456}, expected = "", desc = "Missing x coordinate"},
  {input = {x = 123, y = nil}, expected = "", desc = "Missing y coordinate"},
  {input = {a = 123, b = 456}, expected = "", desc = "Wrong property names"},
}

print("Testing enhanced GPS validation...")
print("=====================================")

local passed = 0
local failed = 0

for i, test in ipairs(test_cases) do
  local result = coords_string_from_map_position(test.input)
  local success = result == test.expected
  
  if success then
    passed = passed + 1
    print(string.format("✓ Test %d: %s", i, test.desc))
  else
    failed = failed + 1
    print(string.format("✗ Test %d: %s", i, test.desc))
    print(string.format("  Expected: '%s', Got: '%s'", test.expected, result))
  end
end

print("=====================================")
print(string.format("Results: %d passed, %d failed", passed, failed))
print(failed == 0 and "🎉 All tests passed!" or "❌ Some tests failed")
