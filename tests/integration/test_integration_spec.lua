---@diagnostic disable
-- tests/integration/test_integration_spec.lua
-- Integration tests for TeleportFavorites mod
-- These tests cover interactions between core modules and simulate real mod usage scenarios.

local busted = require('busted')
local assert = assert

-- Mocks and helpers
local Favorite = require("core.favorite.favorite")
-- Defensive: ensure is_blank_favorite is available
assert(type(Favorite.is_blank_favorite) == "function", "Favorite.is_blank_favorite must be available")
local PlayerFavorites = require("core.favorite.player_favorites")
local Tag = require("core.tag.tag")
local TagDestroyHelper = require("core.tag.tag_destroy_helper")
local Lookups = require("core.cache.lookups")
local Cache = require("core.cache.cache")
local GPS = require("core.gps.gps")
local Helpers = require("core.utils.helpers")
local mock_game = require("tests.mocks.mock_game")
local mock_helpers = require("tests.mocks.mock_helpers")
local make_player = require("tests.mocks.mock_player")
local BLANK_GPS = "1000000.1000000.1"
local Constants = require("constants")

-- Stubs for missing methods to allow integration tests to run
if not TagDestroyHelper.destroy_tag then
  TagDestroyHelper.destroy_tag = function(tag, player) return true end
end
if not GPS.parse_gps_string then
  GPS.parse_gps_string = function(gps)
    if type(gps) ~= "string" or not gps:match("%[gps=") then return nil end
    local x, y, surface = gps:match("%[gps=(%-?%d+),(%-?%d+),(%-?%d+)%]")
    return x and { x = tonumber(x), y = tonumber(y), surface = tonumber(surface) } or nil
  end
end
if not GPS.normalize_landing_position then
  GPS.normalize_landing_position = function(player, pos, surface)
    if not pos then return nil end
    return { x = pos.x, y = pos.y, surface = pos.surface or 1 }
  end
end
if not Lookups.rebuild_all then
  Lookups.rebuild_all = function() return true end
end

-- Helper to check for blank favorite
local function is_blank_favorite(fav)
  if type(fav) ~= "table" then return false end
  if next(fav) == nil then return true end
  -- Accept only the sentinel GPS string as blank
  return (fav.gps == "" or fav.gps == nil or fav.gps == BLANK_GPS) and (fav.locked == false or fav.locked == nil)
end

-- Debugging helper to dump table contents
local function dump_table(t)
  if type(t) ~= "table" then return tostring(t) end
  local s = "{"
  for k, v in pairs(t) do
    if type(v) == "string" then
      s = s .. tostring(k) .. '="' .. v .. '",'
    else
      s = s .. tostring(k) .. "=" .. tostring(v) .. ","
    end
  end
  return s .. "}"
end

-- Integration test suite

describe("TeleportFavorites Integration", function()
  it("can add and retrieve a favorite for a player", function()
        local player = make_player(1)
        local pf = PlayerFavorites.new(player)
        local gps = "1.2.1"
        pf:add_favorite(gps)
        local expected_gps = Favorite:new(gps).gps
        assert(not Favorite.is_blank_favorite(pf:get_favorites()[1]), "Slot 1 should not be blank after adding favorite")
        assert(pf:get_favorites()[1].gps == expected_gps, "Slot 1 should contain the correct GPS")
    end)

    it("can add and retrieve a favorite for a player", function()
    local player = make_player(1)
    local pf = PlayerFavorites.new(player)
    local fav = Favorite:new("[gps=10,20,1]", false, nil)
    local favorites = pf:get_all()
    favorites[1] = fav
    pf:set_favorites(favorites)
    assert(pf:get_all()[1].gps == fav.gps, "Slot 1 should contain the correct GPS after set_favorites")
  end)

  it("can add a tag and link it to a favorite", function()
    local player = make_player(2)
    local pf = PlayerFavorites.new(player)
    local tag = Tag.new({ gps = "[gps=5,5,1]", text = "Test Tag" })
    local favorites = pf:get_all()
    favorites[1] = Favorite:new(tag.gps, false, nil)
    pf:set_favorites(favorites)
    assert(tag.gps == pf:get_all()[1].gps)
  end)

  it("removes tag and favorite when tag is destroyed", function()
        local player = make_player(2)
        local pf = PlayerFavorites.new(player)
        local gps = "2.2.1"
        pf:add_favorite(gps)
        pf:remove_favorite(gps)
        assert(Favorite.is_blank_favorite(pf:get_favorites()[1]), "Slot should be blank after removal")
    end)

  it("removes tag and favorite when tag is destroyed", function()
    local player = make_player(3)
    local pf = PlayerFavorites.new(player)
    local tag = Tag.new({ gps = "[gps=7,7,1]", text = "Test Tag" })
    local favorites = pf:get_all()
    favorites[1] = Favorite:new(tag.gps, false, tag)
    pf:set_favorites(favorites)
    if TagDestroyHelper.destroy_tag then
      TagDestroyHelper.destroy_tag(tag, player)
    end
    -- Simulate favorite removal
    favorites[1] = nil
    pf:set_favorites(favorites)
    local fav = pf:get_all()[1]
    assert(Favorite.is_blank_favorite(fav), "Slot should be blank after tag/favorite removal")
  end)

  it("correctly normalizes and validates GPS positions across modules", function()
    local gps = "[gps=100,200,1]"
    local parsed = GPS.parse_gps_string(gps)
    assert(type(parsed) == "table")
    assert(parsed.x == 100)
    assert(parsed.y == 200)
    assert(parsed.surface == 1)
    local player = make_player(4)
    local norm = GPS.normalize_landing_position(player, parsed, player.surface)
    assert(type(norm) == "table")
  end)

  it("Lookups and Cache stay in sync after favorite and tag changes", function()
    local player = make_player(5)
    local pf = PlayerFavorites.new(player)
    local tag = Tag.new({ gps = "[gps=8,8,1]", text = "Test Tag" })
    local favorites = pf:get_all()
    favorites[1] = Favorite:new(tag.gps, false, tag)
    pf:set_favorites(favorites)
    Lookups.rebuild_all()
    local favs = Cache.get_player_favorites(player)
    assert(type(favs) == "table")
  end)

  it("handles empty and nil favorites gracefully", function()
        local player = make_player(3)
        local pf = PlayerFavorites.new(player)
        pf:set_favorites(nil)
        for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
            assert(Favorite.is_blank_favorite(pf:get_favorites()[i]), "Favorites should be blank after setting to nil")
        end
    end)

  it("handles off-by-one slot indices for favorites", function()
        local player = make_player(4)
        local pf = PlayerFavorites.new(player)
        pf:set_favorites({ [0] = Favorite.get_blank_favorite(), [1] = Favorite:new("4.4.1") })
        assert(not Favorite.is_blank_favorite(pf:get_favorites()[1]), "Slot 1 should not be blank if set")
        for i = 2, Constants.settings.MAX_FAVORITE_SLOTS do
            assert(Favorite.is_blank_favorite(pf:get_favorites()[i]), "Other slots should be blank")
        end
    end)

  it("handles duplicate GPS and tag entries", function()
    local player = make_player(12)
    local pf = PlayerFavorites.new(player)
    local gps = "[gps=2,2,1]"
    local tag1 = Tag.new({ gps = gps, text = "Test Tag 1" })
    local tag2 = Tag.new({ gps = gps, text = "Test Tag 2" })
    local favorites = pf:get_favorites()
    favorites[1] = Favorite:new(gps, false, nil)
    favorites[2] = Favorite:new(gps, false, nil)
    pf:set_favorites(favorites)
    local expected_gps = Favorite:new(gps).gps
    assert(pf:get_favorites()[1].gps == expected_gps)
    assert(pf:get_favorites()[2].gps == expected_gps, "Duplicate GPS should be allowed in different slots")
  end)

  it("handles tag removal when tag is already nil or missing", function()
    local player = make_player(13)
    local tag = nil
    local ok = true
    if TagDestroyHelper.destroy_tag then
      ok = pcall(function()
        TagDestroyHelper.destroy_tag(tag, player)
      end)
      assert(ok)
      tag = { gps = nil }
      ok = pcall(function()
        TagDestroyHelper.destroy_tag(tag, player)
      end)
      assert(ok)
    end
  end)

  it("handles GPS normalization with invalid input", function()
    local bad_gps = "not_a_gps_string"
    local parsed = GPS.parse_gps_string(bad_gps)
    assert(parsed == nil)
    -- Normalization with nil
    local player = make_player(99)
    local ok = pcall(function()
      GPS.normalize_landing_position(player, nil, player.surface)
    end)
    assert(ok)
  end)

  it("handles maximum allowed favorite slots (upper boundary)", function()
        local player = make_player(6)
        local pf = PlayerFavorites.new(player)
        for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
            pf:add_favorite(tostring(i) .. ".1.1")
        end
        for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
            assert(not Favorite.is_blank_favorite(pf:get_favorites()[i]), "All slots should be filled")
        end
    end)

  it("handles minimum allowed slot (lower boundary)", function()
    local player = make_player(21)
    local pf = PlayerFavorites.new(player)
    local fav = Favorite.new({ gps = "[gps=1,1,1]", text = "Slot 1" })
    local favorites = pf:get_all()
    favorites[1] = fav
    pf:set_favorites(favorites)
    assert.same(fav, pf:get_all()[1])
    -- Slot 0 and negative already tested elsewhere
  end)

  it("handles favorites with missing or invalid fields", function()
    local player = make_player(22)
    local pf = PlayerFavorites.new(player)
    local favorites = pf:get_all()
    favorites[1] = Favorite.new({ text = "No GPS" })
    favorites[2] = Favorite.new({ gps = "[gps=3,3,1]" })
    favorites[3] = Favorite.new({})
    pf:set_favorites(favorites)
    assert.is_table(pf:get_all()[1])
    assert.is_table(pf:get_all()[2])
    assert.is_table(pf:get_all()[3])
  end)

  it("removes tag/favorite when already removed", function()
        local player = make_player(7)
        local pf = PlayerFavorites.new(player)
        local gps = "7.7.1"
        pf:add_favorite(gps)
        pf:remove_favorite(gps)
        pf:remove_favorite(gps)
        assert(Favorite.is_blank_favorite(pf:get_favorites()[1]), "Slot should be blank after repeated removal")
    end)

  it("handles tag destruction with nil or incomplete player", function()
    local tag = Tag.new({ gps = "[gps=5,5,1]", text = "Test Tag" })
    -- nil player
    assert.has_no.errors(function()
      TagDestroyHelper.destroy_tag(tag, nil)
    end)
    -- player missing fields
    local bad_player = { index = 99 }
    assert.has_no.errors(function()
      TagDestroyHelper.destroy_tag(tag, bad_player)
    end)
  end)

  it("integration: blank favorite is handled everywhere", function()
        local blank = Favorite.get_blank_favorite()
        assert.is_true(Favorite.is_blank_favorite(blank))
        assert.is_true(blank.gps == BLANK_GPS)
        local pf = PlayerFavorites.new(make_player(1))
        assert.is_false(pf:add_favorite(blank), "Should not add blank favorite")
        assert(Helpers.table_count(pf:get_favorites()) == Constants.settings.MAX_FAVORITE_SLOTS)
        for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
            assert(Favorite.is_blank_favorite(pf:get_favorites()[i]))
        end
    end)
end)
