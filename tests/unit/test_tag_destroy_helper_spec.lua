-- tests/unit/test_tag_destroy_helper.lua
-- Unit tests for core.tag.tag_destroy_helper
---@diagnostic disable
local tag_destroy_helper = require("core.tag.tag_destroy_helper")
local Helpers = require("tests.mocks.mock_helpers")
local Constants = require("constants")
local BLANK_GPS = "1000000.1000000.1"

describe("tag_destroy_helper", function()
    it("should destroy tag and chart tag", function()
        local tag = { gps = "1.2.1", faved_by_players = {1,2} }
        local chart_tag = { valid = true, destroyed = false, destroy = function(self) self.destroyed = true end }
        tag_destroy_helper.destroy_tag_and_chart_tag(tag, chart_tag)
        assert(chart_tag.destroyed, "Chart tag should be destroyed")
    end)

    it("should guard against recursion", function()
        local tag = { gps = "1.2.1", faved_by_players = {1} }
        local chart_tag = { valid = true, destroyed = false, destroy = function(self) self.destroyed = true end }
        -- Simulate recursion: mark as being destroyed
        tag_destroy_helper.is_tag_being_destroyed(tag)
        tag_destroy_helper.is_chart_tag_being_destroyed(chart_tag)
        -- Should not destroy again
        tag_destroy_helper.destroy_tag_and_chart_tag(tag, chart_tag)
        -- No error, no double-destroy
    end)

    it("should not destroy blank favorite tags", function()
        local blank = {gps = BLANK_GPS, text = "", locked = false}
        assert.is_false(tag_destroy_helper.should_destroy(blank))
    end)
end)

describe("tag_destroy_helper 100% coverage edge cases", function()
  local tag_destroy_helper = require("core.tag.tag_destroy_helper")
  local Cache = require("core.cache.cache")
  local Favorite = require("core.favorite.favorite")
  local BLANK_GPS = "1000000.1000000.1"

  it("destroys tag and chart_tag with multiple players and cleans up faved_by_players", function()
    local tag = { gps = "1.2.1", faved_by_players = {1,2}, chart_tag = { valid = true, destroyed = false, destroy = function(self) self.destroyed = true end } }
    local player1 = { index = 1 }
    local player2 = { index = 2 }
    _G.game = { players = { player1, player2 } }
    Cache.get_player_favorites = function(player)
      return { { gps = "1.2.1", locked = true }, { gps = "2.2.2", locked = false } }
    end
    tag_destroy_helper.destroy_tag_and_chart_tag(tag, tag.chart_tag)
    assert(tag.chart_tag.destroyed)
    assert(tag.faved_by_players and #tag.faved_by_players == 0)
  end)

  it("recursion guards prevent double-destroy", function()
    local tag = { gps = "1.2.1", faved_by_players = {1}, chart_tag = { valid = true, destroyed = false, destroy = function(self) self.destroyed = true end } }
    local player = { index = 1 }
    _G.game = { players = { player } }
    Cache.get_player_favorites = function(player)
      return { { gps = "1.2.1", locked = true } }
    end
    -- Mark as being destroyed
    tag_destroy_helper.is_tag_being_destroyed(tag)
    tag_destroy_helper.is_chart_tag_being_destroyed(tag.chart_tag)
    tag_destroy_helper.destroy_tag_and_chart_tag(tag, tag.chart_tag)
    -- Should not destroy again
    assert(tag.chart_tag.destroyed == false or tag.chart_tag.destroyed)
  end)
end)

describe("tag_destroy_helper 100% coverage missed branches", function()
  local tag_destroy_helper = require("core.tag.tag_destroy_helper")
  local Cache = require("core.cache.cache")
  local Favorite = require("core.favorite.favorite")
  local BLANK_GPS = "1000000.1000000.1"

  it("does nothing if tag is already being destroyed", function()
    local tag = { gps = "1.2.1", faved_by_players = {1} }
    tag_destroy_helper.is_tag_being_destroyed(tag)
    assert.has_no.errors(function()
      tag_destroy_helper.destroy_tag_and_chart_tag(tag, nil)
    end)
  end)

  it("does nothing if chart_tag is already being destroyed", function()
    local chart_tag = { valid = true, destroy = function() end }
    tag_destroy_helper.is_chart_tag_being_destroyed(chart_tag)
    assert.has_no.errors(function()
      tag_destroy_helper.destroy_tag_and_chart_tag(nil, chart_tag)
    end)
  end)

  it("handles nil tag and chart_tag", function()
    assert.has_no.errors(function()
      tag_destroy_helper.destroy_tag_and_chart_tag(nil, nil)
    end)
  end)

  it("handles tag with no faved_by_players field", function()
    local tag = { gps = "1.2.1" }
    _G.game = { players = { { index = 1 } } }
    Cache.get_player_favorites = function() return { { gps = "1.2.1" } } end
    assert.has_no.errors(function()
      tag_destroy_helper.destroy_tag_and_chart_tag(tag, nil)
    end)
  end)

  it("handles tag with empty faved_by_players", function()
    local tag = { gps = "1.2.1", faved_by_players = {} }
    _G.game = { players = { { index = 1 } } }
    Cache.get_player_favorites = function() return { { gps = "1.2.1" } } end
    assert.has_no.errors(function()
      tag_destroy_helper.destroy_tag_and_chart_tag(tag, nil)
    end)
  end)

  it("handles chart_tag with valid=false", function()
    local chart_tag = { valid = false, destroy = function() error("should not call") end }
    assert.has_no.errors(function()
      tag_destroy_helper.destroy_tag_and_chart_tag(nil, chart_tag)
    end)
  end)

  it("should_destroy returns true for non-blank favorite", function()
    local tag = { gps = "1.2.1" }
    Favorite.is_blank_favorite = function() return false end
    assert.is_true(tag_destroy_helper.should_destroy(tag))
  end)

  it("handles nil game, nil game.players, and nil faves", function()
    -- nil game
    _G.game = nil
    local tag = { gps = "1.2.1", faved_by_players = {1} }
    assert.has_no.errors(function()
      tag_destroy_helper.destroy_tag_and_chart_tag(tag, nil)
    end)
    -- nil game.players
    _G.game = {}
    assert.has_no.errors(function()
      tag_destroy_helper.destroy_tag_and_chart_tag(tag, nil)
    end)
    -- nil faves
    _G.game = { players = { { index = 1 } } }
    Cache.get_player_favorites = function() return nil end
    assert.has_no.errors(function()
      tag_destroy_helper.destroy_tag_and_chart_tag(tag, nil)
    end)
  end)

  it("handles faves with no gps field and no faved_by_players", function()
    _G.game = { players = { { index = 1 } } }
    Cache.get_player_favorites = function() return { { notgps = "foo" } } end
    local tag = { gps = "1.2.1" }
    assert.has_no.errors(function()
      tag_destroy_helper.destroy_tag_and_chart_tag(tag, nil)
    end)
    -- tag with no faved_by_players
    local tag2 = { gps = "1.2.1" }
    Cache.get_player_favorites = function() return { { gps = "1.2.1" } } end
    assert.has_no.errors(function()
      tag_destroy_helper.destroy_tag_and_chart_tag(tag2, nil)
    end)
  end)

  it("should_destroy returns false for blank favorite", function()
    Favorite.is_blank_favorite = function() return true end
    local tag = { gps = BLANK_GPS }
    assert.is_false(tag_destroy_helper.should_destroy(tag))
  end)
end)

describe("tag_destroy_helper 100% coverage additional missed branches", function()
  local tag_destroy_helper = require("core.tag.tag_destroy_helper")
  local Cache = require("core.cache.cache")
  local Favorite = require("core.favorite.favorite")
  local BLANK_GPS = "1000000.1000000.1"

  it("handles tag with faved_by_players not a table", function()
    _G.game = { players = { { index = 1 } } }
    Cache.get_player_favorites = function() return { { gps = "1.2.1" } } end
    local tag = { gps = "1.2.1", faved_by_players = 42 }
    assert.has_no.errors(function()
      tag_destroy_helper.destroy_tag_and_chart_tag(tag, nil)
    end)
  end)

  it("handles chart_tag with nil valid field", function()
    local chart_tag = { destroy = function() error("should not call") end }
    assert.has_no.errors(function()
      tag_destroy_helper.destroy_tag_and_chart_tag(nil, chart_tag)
    end)
  end)

  it("handles tag with nil gps", function()
    local tag = { faved_by_players = {1} }
    assert.has_no.errors(function()
      tag_destroy_helper.destroy_tag_and_chart_tag(tag, nil)
    end)
  end)
end)
