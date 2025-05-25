-- tests/unit/test_gps.lua
-- Unit tests for core.gps.gps
local GPS = require("core.gps.gps")

local function test_gps_from_map_position()
  local pos = {x=123, y=456}
  local gps = GPS.gps_from_map_position(pos, 2)
  assert(type(gps) == "string" and gps:find("2$"), "Should encode surface index")
end

local function test_map_position_from_gps()
  local gps = "123.456.2"
  local pos = GPS.map_position_from_gps(gps)
  assert(pos.x == 123 and pos.y == 456, "Should decode x/y from gps string")
end

local function test_coords_string_from_gps()
  local gps = "123.456.2"
  local coords = GPS.coords_string_from_gps(gps)
  assert(coords == "123.456", "Should return coords string")
end

local function test_get_surface_index()
  local gps = "123.456.2"
  local idx = GPS.get_surface_index(gps)
  assert(idx == 2, "Should extract surface index")
  assert(GPS.get_surface_index("bad.gps") == 1, "Should default to 1 on bad input")
end

local function run_all()
  test_gps_from_map_position()
  test_map_position_from_gps()
  test_coords_string_from_gps()
  test_get_surface_index()
  print("All GPS tests passed.")
end

run_all()
