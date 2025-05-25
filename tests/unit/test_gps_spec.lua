---@diagnostic disable
local GPS = require("core.gps.gps")
local Favorite = require("core.favorite.favorite")
local Helpers = require("tests.mocks.mock_helpers")
local Constants = require("constants")
local BLANK_GPS = "1000000.1000000.1"

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

local function test_blank_gps()
  assert(GPS.map_position_from_gps(BLANK_GPS).x == 0, "BLANK_GPS should decode to x=0")
  assert(GPS.map_position_from_gps(BLANK_GPS).y == 0, "BLANK_GPS should decode to y=0")
  assert(GPS.get_surface_index(BLANK_GPS) == 1, "BLANK_GPS should have surface index 1")
  assert(GPS.coords_string_from_gps(BLANK_GPS) == "1000000.1000000", "BLANK_GPS should have the corresponding coords string")
end

local function test_parse_gps_string_edge_cases()
  local gps_helpers = require("core.utils.gps_helpers")
  assert(gps_helpers.parse_gps_string(nil) == nil, "Should return nil for nil input")
  assert(gps_helpers.parse_gps_string(12345) == nil, "Should return nil for non-string input")
  assert(gps_helpers.parse_gps_string("not.a.gps") == nil, "Should return nil for badly formatted string")
  assert(gps_helpers.parse_gps_string("1.2.3").x == 1, "Should parse valid gps string")
end

local function run_all()
  test_gps_from_map_position()
  test_map_position_from_gps()
  test_coords_string_from_gps()
  test_get_surface_index()
  test_blank_gps()
  test_parse_gps_string_edge_cases()
  print("All GPS tests passed.")
end

run_all()

describe("Favorite GPS handling", function()
    it("should recognize blank gps as blank favorite", function()
        assert.is_true(Favorite.is_blank_favorite({gps = BLANK_GPS}))
    end)
    it("should decode gps string to position", function()
        local pos = GPS.map_position_from_gps("123.456.1")
        assert.is_not_nil(pos)
        if pos then
            assert.is_true(pos.x == 123)
            assert.is_true(pos.y == 456)
        end
    end)
    it("BLANK_GPS should decode to x=0, y=0", function()
        local pos = GPS.map_position_from_gps(BLANK_GPS)
        assert.is_not_nil(pos)
        if pos then
            assert.is_true(pos.x == 0)
            assert.is_true(pos.y == 0)
        end
    end)
end)

describe("gps_helpers 100% coverage edge cases", function()
  local gps_helpers = require("core.utils.gps_helpers")
  it("map_position_from_gps returns nil for nil, non-string, or bad string", function()
    assert.is_nil(gps_helpers.map_position_from_gps(nil))
    assert.is_nil(gps_helpers.map_position_from_gps(12345))
    assert.is_nil(gps_helpers.map_position_from_gps("not.a.gps"))
  end)
  it("get_surface_index returns 1 for nil, non-string, or bad string", function()
    assert.equals(1, gps_helpers.get_surface_index(nil))
    assert.equals(1, gps_helpers.get_surface_index(12345))
    assert.equals(1, gps_helpers.get_surface_index("not.a.gps"))
  end)
  it("normalize_landing_position returns nil if pos is nil", function()
    assert.is_nil(gps_helpers.normalize_landing_position({}, nil, 1))
  end)
  it("normalize_landing_position handles all surface types", function()
    local pos = { x = 1, y = 2 }
    -- number
    local r = gps_helpers.normalize_landing_position({}, pos, 5)
    assert.same({ x = 1, y = 2, surface = 5 }, r)
    -- table with index
    r = gps_helpers.normalize_landing_position({}, pos, { index = 7 })
    assert.same({ x = 1, y = 2, surface = 7 }, r)
    -- string with matching surface in game.surfaces
    _G.game = { surfaces = { foo = { index = 9 } } }
    r = gps_helpers.normalize_landing_position({}, pos, "foo")
    assert.same({ x = 1, y = 2, surface = 9 }, r)
    -- string with no matching surface
    r = gps_helpers.normalize_landing_position({}, pos, "bar")
    assert.same({ x = 1, y = 2, surface = 1 }, r)
  end)
end)
