-- Shared Factorio test environment (globals, settings, etc.)
require("tests.mocks.factorio_test_env")

local custom_assert = {
  equals = function(a, b, msg) if a ~= b then error(msg or (tostring(a) .. " ~= " .. tostring(b))) end end,
  is_true = function(a, msg) if not a then error(msg or "expected true but was false") end end,
  is_false = function(a, msg) if a then error(msg or "expected false but was true") end end,
  is_nil = function(a, msg) if a ~= nil then error(msg or ("expected nil but was " .. tostring(a))) end end,
  is_not_nil = function(a, msg) if a == nil then error(msg or "expected not nil but was nil") end end,
  not_equals = function(a, b, msg) if a == b then error(msg or (tostring(a) .. " == " .. tostring(b))) end end,
  is_table = function(a, msg) if type(a) ~= "table" then error(msg or ("expected table but was " .. type(a))) end end
}
local assert = custom_assert

local Constants = require("constants")
local mock_player_data = require("tests.mocks.mock_player_data")

describe("Constants.settings", function()
  it("should have correct default values", function()
    local _ = mock_player_data.create_mock_player_data()
    assert.equals(Constants.settings.CHART_TAG_CLICK_RADIUS, 10)
    assert.equals(Constants.settings.MAX_FAVORITE_SLOTS, 10)
    assert.equals(Constants.settings.DEFAULT_COORDS_UPDATE_INTERVAL, 15)
    assert.equals(Constants.settings.DEFAULT_HISTORY_UPDATE_INTERVAL, 30)
    assert.equals(Constants.settings.MIN_UPDATE_INTERVAL, 5)
    assert.equals(Constants.settings.MAX_UPDATE_INTERVAL, 59)
    assert.equals(Constants.settings.BLANK_GPS, "1000000.1000000.1")
    assert.equals(Constants.settings.FAVORITES_ON, "favorites_on")
    assert.equals(Constants.settings.BOUNDING_BOX_TOLERANCE, 4)
    assert.equals(Constants.settings.TAG_TEXT_MAX_LENGTH, 256)
  end)

  it("should have correct command definitions", function()
    local _ = mock_player_data.create_mock_player_data()
    assert.equals(Constants.COMMANDS.DELETE_FAVORITE_BY_SLOT, "tf-delete-favorite-slot")
  end)
end)
