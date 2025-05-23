-- tests/250523/test_favorite.lua
-- EmmyLua @type strict
-- Test suite for core/favorite/favorite.lua
local assert = require("luassert")
local busted = require("busted")
local describe = busted.describe
local it = busted.it
local Favorite = require("core.favorite.favorite")

describe("Favorite", function()
  it("should create a favorite with correct fields", function()
    local fav = Favorite:new("100.200.1", true)
    assert.are.equal(fav.gps, "100.200.1")
    assert.is_true(fav.locked)
  end)

  it("should update gps and toggle locked", function()
    local fav = Favorite:new("100.200.1", false)
    fav:update_gps("200.300.2")
    assert.are.equal(fav.gps, "200.300.2")
    fav:toggle_locked()
    assert.is_true(fav.locked)
  end)

  it("should create a blank favorite", function()
    local blank = Favorite.get_blank_favorite()
    assert.are.equal(blank.gps, "")
    assert.is_false(blank.locked)
  end)
end)
