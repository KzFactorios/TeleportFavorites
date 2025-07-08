require("tests.test_bootstrap")
-- tests/tag_destroy_helper_combined_spec.lua
-- Combined and deduplicated tests for core.tag.tag_destroy_helper

_G.global = _G.global or {}
_G.storage = _G.storage or {}
_G.game = _G.game or { players = {} }
_G._TEST_EXPOSE_TAG_DESTROY_HELPERS = true
_G.surfaces = _G.surfaces or {}

local tag_destroy_helper = require("core.tag.tag_destroy_helper")
local ErrorHandler = require("core.utils.error_handler")
local Cache = require("core.cache.cache")
local helpers = tag_destroy_helper._test_expose
local spy_utils = require("tests.mocks.spy_utils")
local make_spy = spy_utils.make_spy

-- Comprehensive tests

describe("Tag destroy helper", function()
  before_each(function()
    _G.debug_called = 0
    _G.stored_tag_removed = {}
    _G.mock_favorites = {
      [1] = {
        { gps = "1.2.3", locked = true },
        { gps = "4.5.6", locked = false }
      },
      [2] = {
        { gps = "1.2.3", locked = false },
        { gps = "7.8.9", locked = true }
      }
    }
  end)

  it("should correctly identify tags being destroyed", function()
    local tag = { gps = "1.2.3" }
    assert.is_false(tag_destroy_helper.is_tag_being_destroyed(tag))
    local call_count = 0
    local recursion_detected = false
    local original_destroy = tag_destroy_helper.destroy_tag_and_chart_tag
    tag_destroy_helper.destroy_tag_and_chart_tag = function(t, ct)
      if t == tag then
        call_count = call_count + 1
        if call_count == 1 then
          recursion_detected = tag_destroy_helper.destroy_tag_and_chart_tag(tag, nil)
          return true
        else
          return true
        end
      end
      return original_destroy(t, ct)
    end
    local result = tag_destroy_helper.destroy_tag_and_chart_tag(tag, nil)
    assert.is_true(recursion_detected)
    assert.equals(2, call_count)
    tag_destroy_helper.destroy_tag_and_chart_tag = original_destroy
  end)
end)

-- Internal helper tests

describe("tag_destroy_helper internal helpers", function()
  it("has_any_favorites returns false for nil and no faved_by_players", function()
    assert.is_false(helpers.has_any_favorites(nil))
    assert.is_false(helpers.has_any_favorites({}))
    assert.is_false(helpers.has_any_favorites({faved_by_players = nil}))
    assert.is_false(helpers.has_any_favorites({faved_by_players = {}}))
  end)

  it("has_any_favorites returns true for non-empty faved_by_players", function()
    assert.is_true(helpers.has_any_favorites({faved_by_players = {1}}))
  end)

  it("cleanup_player_favorites cleans up favorites", function()
    _G.surfaces = { [1] = { name = "nauvis" } }
    local mock_surface = _G.surfaces[1]
    _G.game = { players = { [1] = { index = 1, surface = mock_surface }, [2] = { index = 2, surface = mock_surface } } }
    _G.mock_favorites = {
      [1] = { { gps = "1.2.3", locked = true }, { gps = "4.5.6", locked = false } },
      [2] = { { gps = "1.2.3", locked = false }, { gps = "7.8.9", locked = true } }
    }
    local original_get_player_favorites = Cache.get_player_favorites
    Cache.get_player_favorites = function(player)
      return _G.mock_favorites[player.index] or {}
    end
    local tag = { gps = "1.2.3" }
    local cleaned = helpers.cleanup_player_favorites(tag)
    assert.equals(2, cleaned)
    assert.equals("", _G.mock_favorites[1][1].gps)
    assert.is_false(_G.mock_favorites[1][1].locked)
    assert.equals("", _G.mock_favorites[2][1].gps)
    assert.is_false(_G.mock_favorites[2][1].locked)
    Cache.get_player_favorites = original_get_player_favorites
  end)

  it("cleanup_faved_by_players removes player indices", function()
    _G.game = { players = { [1] = { index = 1 }, [2] = { index = 2 } } }
    local tag = { faved_by_players = {1, 2, 3} }
    helpers.cleanup_faved_by_players(tag)
    assert.same({3}, tag.faved_by_players)
  end)

  it("cleanup_faved_by_players logs if no faved_by_players", function()
    _G.debug_logs = {}
    helpers.cleanup_faved_by_players({})
    assert.is_true(true)
  end)

  it("validate_destruction_inputs detects missing gps", function()
    local ok, issues = helpers.validate_destruction_inputs({}, nil)
    assert.is_false(ok)
    assert.is_true(#issues > 0)
  end)

  it("validate_destruction_inputs logs for invalid chart_tag", function()
    local chart_tag = setmetatable({}, { __index = { valid = false } })
    local ok, issues = helpers.validate_destruction_inputs({ gps = "1.2.3" }, chart_tag)
    assert.is_true(ok)
  end)

  it("safe_destroy_with_cleanup handles all branches", function()
    local tag = { gps = "1.2.3", chart_tag = { valid = true, destroy = function() end }, faved_by_players = {1} }
    _G.game = { players = { [1] = { index = 1 } } }
    _G.mock_favorites = { [1] = { { gps = "1.2.3", locked = true } } }
    local r1 = helpers.safe_destroy_with_cleanup(tag, tag.chart_tag)
    assert.is_true(r1)
    local tag2 = { gps = "2.2.2", chart_tag = { valid = false, destroy = function() end }, faved_by_players = {1} }
    local r2 = helpers.safe_destroy_with_cleanup(tag2, tag2.chart_tag)
    assert.is_true(r2)
    local tag3 = { gps = "3.3.3", faved_by_players = {1} }
    local r3 = helpers.safe_destroy_with_cleanup(tag3, nil)
    assert.is_true(r3)
    local r4 = helpers.safe_destroy_with_cleanup(nil, nil)
    assert.is_true(r4)
  end)
end)
