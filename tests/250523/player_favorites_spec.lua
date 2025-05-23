-- tests/250523/test_player_favorites.lua
-- EmmyLua @type strict
-- Test suite for core/favorite/player_favorites.lua
local assert = require("luassert")
local busted = require("busted")
local describe = busted.describe
local it = busted.it
local PlayerFavorites = require("core.favorite.player_favorites")
local Favorite = require("core.favorite.favorite")

describe("PlayerFavorites", function()
  local dummy_player = { index = 1, surface = { index = 1 } }

  it("should add and retrieve favorites", function()
    local pf = PlayerFavorites:new(dummy_player)
    pf:add_favorite("100.200.1")
    local found = false
    for _, fav in ipairs(pf.favorites) do
      if fav.gps == "100.200.1" then found = true end
    end
    assert.is_true(found)
  end)

  it("should not add duplicate favorites if slots are full", function()
    local pf = PlayerFavorites:new(dummy_player)
    for i = 1, #pf.favorites do
      pf.favorites[i].gps = "filled" .. i
    end
    assert.is_false(pf:add_favorite("newgps"))
  end)
end)
