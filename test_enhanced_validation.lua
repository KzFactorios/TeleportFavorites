-- Test script for enhanced GPS validation
local GPSCore = require("core.utils.gps_core")

-- Test enhanced coords_string_from_map_position validation
print("Testing coords_string_from_map_position enhanced validation:")

-- Valid inputs
print("Valid {x=123, y=456}:", GPSCore.coords_string_from_map_position({x=123, y=456}))
print("Valid {x=-5, y=10}:", GPSCore.coords_string_from_map_position({x=-5, y=10}))
print("Valid {x=0, y=0}:", GPSCore.coords_string_from_map_position({x=0, y=0}))

-- Invalid inputs - should all return ""
print("Invalid nil:", GPSCore.coords_string_from_map_position(nil))
print("Invalid string:", GPSCore.coords_string_from_map_position("test"))
print("Invalid number:", GPSCore.coords_string_from_map_position(123))
print("Invalid {x='abc', y=456}:", GPSCore.coords_string_from_map_position({x='abc', y=456}))
print("Invalid {x=123}:", GPSCore.coords_string_from_map_position({x=123}))
print("Invalid {}:", GPSCore.coords_string_from_map_position({}))

print("\nTesting coords_string_from_gps enhanced validation:")

-- Valid GPS strings
print("Valid '123.456.1':", GPSCore.coords_string_from_gps("123.456.1"))
print("Valid '-005.010.2':", GPSCore.coords_string_from_gps("-005.010.2"))

-- Invalid inputs - should all return ""
print("Invalid nil:", GPSCore.coords_string_from_gps(nil))
print("Invalid number:", GPSCore.coords_string_from_gps(123))
print("Invalid BLANK_GPS:", GPSCore.coords_string_from_gps("1000000.1000000.1"))
print("Invalid '':", GPSCore.coords_string_from_gps(""))
print("Invalid 'abc':", GPSCore.coords_string_from_gps("abc"))

print("\nAll tests completed!")
