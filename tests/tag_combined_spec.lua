require("tests.test_bootstrap")
-- tests/tag_combined_spec.lua
-- Combined and deduplicated tests for core.tag.tag

_G.global = _G.global or {}
_G.storage = _G.storage or {}
_G.remote = _G.remote or setmetatable({}, {__index = function() return function() end end})
_G.defines = _G.defines or {events = {}}
_G._TEST_EXPOSE_TAG_HELPERS = true
_G.surfaces = _G.surfaces or {}

local Tag = require("core.tag.tag")
local ErrorHandler = require("core.utils.error_handler")
local Cache = require("core.cache.cache")
local ChartTagUtils = require("core.utils.chart_tag_utils")
local LocaleUtils = require("core.utils.locale_utils")
local ChartTagSpecBuilder = require("core.utils.chart_tag_spec_builder")
local helpers = Tag._test_expose
local mock_player_data = require("tests.mocks.mock_player_data")

-- Basic Tag object tests

describe("Tag object", function()
  it("should create a tag with correct properties", function()
    local tag = Tag.new("gps_string")
    assert.equals(tag.gps, "gps_string")
    assert.is_nil(tag.text)
    assert.is_nil(tag.owner)
  end)

  it("should integrate with mock player data for tags", function()
    local mock = mock_player_data.create_mock_player_data({
      tag_ids = {"tagA", "tagB"},
      player_names = {"TagTester"},
      favorites_config = {single_cases = {2}}
    })
    local favs = mock.favorites["TagTester_2"]
    assert.is_table(favs)
    assert.equals(#favs, 2)
    for _, tag_id in ipairs(favs) do
      assert.is_string(tag_id)
    end
  end)
end)

-- Internal helper tests

describe("tag.lua internal helpers", function()
  it("collect_linked_favorites returns empty for no players", function()
    _G.game = { players = {} }
    local result = helpers.collect_linked_favorites("1.2.3")
    assert.same({}, result)
  end)

  it("collect_linked_favorites returns matches only", function()
    _G.game = { players = { [1] = { index = 1 }, [2] = { index = 2 } } }
    _G.mock_favorites = {
      [1] = { { gps = "1.2.3" }, { gps = "4.5.6" } },
      [2] = { { gps = "1.2.3" }, { gps = "7.8.9" } }
    }
    Cache.get_player_favorites = function(player) return _G.mock_favorites[player.index] or {} end
    local result = helpers.collect_linked_favorites("1.2.3")
    assert.equals(2, #result)
    assert.equals("1.2.3", result[1].gps)
    assert.equals("1.2.3", result[2].gps)
  end)

  it("create_new_chart_tag returns new tag on success", function()
    local called = false
    ChartTagSpecBuilder.build = function(pos, chart_tag, player, text, set_ownership)
      return { position = pos, text = text, last_user = player and player.name or nil }
    end
    ChartTagUtils.safe_add_chart_tag = function(force, surface, chart_tag_spec, player)
      called = true
      return { valid = true }
    end
    local player = { force = { name = "force" }, surface = {}, name = "Player1" }
    local pos = { x = 1, y = 2 }
    local chart_tag = { text = "Test" }
    local new_tag, err = helpers.create_new_chart_tag(player, pos, chart_tag)
    assert.is_true(called)
    assert.is_table(new_tag)
    assert.is_nil(err)
  end)

  it("create_new_chart_tag returns error on failure", function()
    ChartTagSpecBuilder.build = function() return {} end
    ChartTagUtils.safe_add_chart_tag = function() return nil end
    LocaleUtils.get_error_string = function(_, key) return "ERR:"..key end
    local player = { force = { name = "force" }, surface = {}, name = "Player1" }
    local pos = { x = 1, y = 2 }
    local chart_tag = { text = "Test" }
    local new_tag, err = helpers.create_new_chart_tag(player, pos, chart_tag)
    assert.is_nil(new_tag)
    assert.equals("ERR:destination_not_available", err)
  end)

  it("update_favorites_gps updates all entries", function()
    local favs = { { gps = "old" }, { gps = "old" } }
    helpers.update_favorites_gps(favs, "new")
    assert.equals("new", favs[1].gps)
    assert.equals("new", favs[2].gps)
  end)

  it("cleanup_old_chart_tag destroys valid tag", function()
    local destroyed = false
    local chart_tag = { valid = true, destroy = function() destroyed = true end }
    helpers.cleanup_old_chart_tag(chart_tag)
    assert.is_true(destroyed)
  end)

  it("cleanup_old_chart_tag skips invalid or nil tag", function()
    local chart_tag = { valid = false, destroy = function() error("Should not call destroy") end }
    helpers.cleanup_old_chart_tag(chart_tag)
    helpers.cleanup_old_chart_tag(nil)
    assert.is_true(true)
  end)
end)

-- Comprehensive/edge-case tests from tag_100_spec.lua can be appended here as needed for full coverage.
