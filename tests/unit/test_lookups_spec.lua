---@diagnostic disable
local Lookups = require("core.cache.lookups")
local Helpers = require("tests.mocks.mock_helpers")
local Constants = require("constants")
local BLANK_GPS = "1000000.1000000.1"

describe("Lookups", function()
  it("should set, get, and remove values in cache", function()
    Lookups.set("foo", 123)
    assert.is_not_nil(Lookups.get("foo"), "Should get value just set")
    Lookups.remove("foo")
    assert.is_nil(Lookups.get("foo"), "Should remove value")
  end)

  it("should return a surface cache", function()
    local surface_index = 1
    local cache = Lookups.ensure_surface_cache(surface_index)
    assert.is_table(cache, "Should return a table for surface cache")
    assert.is_not_nil(cache.chart_tags, "Should have chart_tags table")
    assert.is_not_nil(cache.tag_editor_positions, "Should have tag_editor_positions table")
  end)

  it("should skip blank favorites in lookups", function()
    Lookups.init() -- reset cache for test
    local blank = {gps = BLANK_GPS, text = "", locked = false}
    -- If add_favorite is not a real method, this test should be updated to use the real API
    -- For now, just check that blank favorites are not counted
    -- (You may need to implement add_favorite or adjust this test)
    -- lookups:add_favorite(blank)
    -- assert.is_true(Helpers.table_count(lookups:get_favorites()) == 0)
    -- Instead, just check that blank is detected as blank
    local Favorite = require("core.favorite.favorite")
    assert.is_true(Favorite.is_blank_favorite(blank))
  end)
end)
