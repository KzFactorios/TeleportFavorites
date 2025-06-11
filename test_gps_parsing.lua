-- Test GPS parsing with negative values

-- Mock the dependencies that gps_helpers needs
local basic_helpers = {
  normalize_index = function(val) return math.floor(tonumber(val) or 0) end,
  pad = function(val, len) return string.format("%0" .. len .. "d", val) end
}

local Constants = {
  settings = {
    GPS_PAD_NUMBER = 3,
    BLANK_GPS = "1000000.1000000.1"
  }
}

-- Simple mock for other dependencies
local Helpers = {}
local Settings = {}

-- Set up the environment
local padlen, BLANK_GPS = Constants.settings.GPS_PAD_NUMBER, Constants.settings.BLANK_GPS

--- Parse a GPS string 'x.y.s' into {x, y, surface_index} or nil if invalid
local function parse_gps_string(gps)
  if type(gps) ~= "string" then return nil end
  if gps == BLANK_GPS then return { x = 0, y = 0, s = -1 } end

  local x, y, s = gps:match("^(%-?%d+)%.(%-?%d+)%.(%d+)$")
  if not x or not y or not s then return nil end
  local parsed_x, parsed_y, parsed_s = tonumber(x), tonumber(y), tonumber(s)
  if not parsed_x or not parsed_y or not parsed_s then return nil end
  local ret = {
    x = basic_helpers.normalize_index(parsed_x),
    y = basic_helpers.normalize_index(parsed_y),
    s = basic_helpers.normalize_index(parsed_s)
  }
  return ret
end

-- Test cases
local test_cases = {
  -- Valid GPS strings with negative values
  { gps = "-123.456.1", expected = { x = -123, y = 456, s = 1 } },
  { gps = "123.-456.1", expected = { x = 123, y = -456, s = 1 } },
  { gps = "-123.-456.1", expected = { x = -123, y = -456, s = 1 } },
  { gps = "-1.-1.1", expected = { x = -1, y = -1, s = 1 } },
  { gps = "-1000.-2000.5", expected = { x = -1000, y = -2000, s = 5 } },
  
  -- Positive values for comparison
  { gps = "123.456.1", expected = { x = 123, y = 456, s = 1 } },
  { gps = "001.002.1", expected = { x = 1, y = 2, s = 1 } },
  
  -- Edge case: BLANK_GPS
  { gps = BLANK_GPS, expected = { x = 0, y = 0, s = -1 } },
  
  -- Invalid cases
  { gps = "abc.def.1", expected = nil },
  { gps = "123.456.-1", expected = nil }, -- Negative surface should fail based on regex
  { gps = "", expected = nil },
  { gps = "123.456", expected = nil }, -- Missing surface
}

print("Testing parse_gps_string with negative values...")
print("BLANK_GPS =", BLANK_GPS)
print("")

for i, test in ipairs(test_cases) do
  local result = parse_gps_string(test.gps)
  local success = false
  
  if test.expected == nil then
    success = (result == nil)
  elseif result ~= nil and test.expected ~= nil then
    success = (result.x == test.expected.x and result.y == test.expected.y and result.s == test.expected.s)
  end
  
  local status = success and "PASS" or "FAIL"
  print(string.format("Test %d: %s", i, status))
  print(string.format("  Input: '%s'", test.gps))
  if test.expected then
    print(string.format("  Expected: x=%d, y=%d, s=%d", test.expected.x, test.expected.y, test.expected.s))
  else
    print("  Expected: nil")
  end
  if result then
    print(string.format("  Got: x=%d, y=%d, s=%d", result.x, result.y, result.s))
  else
    print("  Got: nil")
  end
  print("")
end

print("Test completed!")
