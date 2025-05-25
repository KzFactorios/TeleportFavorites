---@diagnostic disable
local Favorite = require("core.favorite.favorite")
local PlayerFavorites = require("core.favorite.player_favorites")
local Helpers = require("tests.mocks.mock_helpers")
local make_player = require("tests.mocks.mock_player")
local BLANK_GPS = "1000000.1000000.1"
local defines = _G.defines or { render_mode = { game = 0, chart = 1, chart_zoomed_in = 2, chart_zoomed_out = 3 } }
local Constants = require("constants")

describe("PlayerFavorites", function()
    it("should create new instance and get all favorites", function()
        local player = make_player(1)
        local pf = PlayerFavorites.new(player)
        local all = pf:get_all()
        assert(type(all) == "table" and Helpers.table_count(all) == Constants.settings.MAX_FAVORITE_SLOTS, "Should have correct number of slots")
    end)

    it("should add and remove favorite", function()
        local player = make_player(1)
        local pf = PlayerFavorites.new(player)
        local gps = "1.2.1"
        assert(pf:add_favorite(gps), "Should add favorite")
        assert(pf:get_favorite_by_gps(gps), "Should retrieve added favorite")
        pf:remove_favorite(gps)
        assert(not pf:get_favorite_by_gps(gps), "Should remove favorite")
    end)

    it("should fill all slots and handle overflow", function()
        local player = make_player(1)
        local pf = PlayerFavorites.new(player)
        -- Fill all slots
        for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
            local gps = tostring(i) .. ".0.0"
            assert(pf:add_favorite(gps), "Should add favorite to slot " .. i)
        end
        -- All slots should be filled
        for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
            local gps = tostring(i) .. ".0.0"
            assert(pf:get_favorite_by_gps(gps), "Favorite should exist for " .. gps)
        end
        -- Try to add one more (should fail)
        assert(not pf:add_favorite("overflow.gps"), "Should not add favorite when full")
    end)

    it("should add to first and last slot", function()
        local player = make_player(1)
        local pf = PlayerFavorites.new(player)
        local first_gps = "first.1.1"
        local last_gps = "last.9.9"
        assert(pf:add_favorite(first_gps), "Should add to first slot")
        for i = 2, Constants.settings.MAX_FAVORITE_SLOTS - 1 do
            pf:add_favorite("mid." .. i)
        end
        assert(pf:add_favorite(last_gps), "Should add to last slot")
        assert(pf:get_favorite_by_gps(first_gps), "First slot favorite exists")
        assert(pf:get_favorite_by_gps(last_gps), "Last slot favorite exists")
        pf:remove_favorite(first_gps)
        pf:remove_favorite(last_gps)
        assert(not pf:get_favorite_by_gps(first_gps), "First slot favorite removed")
        assert(not pf:get_favorite_by_gps(last_gps), "Last slot favorite removed")
    end)

    it("should not error when removing nonexistent favorite", function()
        local player = make_player(1)
        local pf = PlayerFavorites.new(player)
        pf:remove_favorite("not.exists") -- Should not error
        -- No assert needed, as the absence of error is the success condition
    end)

    it("should handle duplicate gps correctly", function()
        local player = make_player(1)
        local pf = PlayerFavorites.new(player)
        local gps = "dup.1.1"
        assert(pf:add_favorite(gps), "Should add first instance")
        -- Try to add again (should add to next slot, not overwrite)
        assert(pf:add_favorite(gps), "Should add duplicate GPS to next slot")
        -- Both slots should reference the same GPS string, but only one should be in the lookup
        local count = 0
        for _, fav in ipairs(pf:get_all()) do
            if fav.gps == gps then count = count + 1 end
        end
        assert(count == 2, "Duplicate GPS should appear in two slots")
    end)

    it("should set favorites correctly", function()
        local player = make_player(1)
        local pf = PlayerFavorites.new(player)
        local new_faves = {}
        for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
            new_faves[i] = Favorite.get_blank_favorite()
            new_faves[i].gps = "set." .. i
        end
        pf:set_favorites(new_faves)
        for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
            assert(pf:get_all()[i].gps == "set." .. i, "set_favorites should update all slots")
        end
    end)

    it("should validate gps correctly", function()
        assert(PlayerFavorites.validate_gps("1.2.3"), "Valid GPS should pass")
        local ok, msg = PlayerFavorites.validate_gps("")
        assert(not ok and msg, "Empty GPS should fail validation")
        ok, msg = PlayerFavorites.validate_gps(nil)
        assert(not ok and msg, "Nil GPS should fail validation")
    end)

    it("should remove favorite with no match silently", function()
        local player = make_player(1)
        local pf = PlayerFavorites.new(player)
        pf:remove_favorite("not-a-gps")
        for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
            assert(Favorite.is_blank_favorite(pf:get_all()[i]), "Slot should remain blank if GPS not found")
        end
    end)

    it("should handle set favorites with empty and invalid tables", function()
        local player = make_player(1)
        local pf = PlayerFavorites.new(player)
        pf:set_favorites({})
        for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
            assert(Favorite.is_blank_favorite(pf:get_all()[i]), "Favorites should be blank after setting to empty table")
        end
        -- Set to table with nils
        pf:set_favorites({nil, nil, nil})
        for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
            assert(Favorite.is_blank_favorite(pf:get_all()[i]), "Favorites should be blank after setting to all nils")
        end
        -- Set to table with fewer than MAX_FAVORITE_SLOTS
        local partial = {}
        for i = 1, 2 do partial[i] = Favorite.get_blank_favorite() end
        pf:set_favorites(partial)
        for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
            assert(Favorite.is_blank_favorite(pf:get_all()[i]), "All slots should be blank after partial set")
        end
    end)

    it("should handle new favorites with missing or invalid slots", function()
        -- Simulate persistent favorites with missing/non-table entries
        local player = make_player(1)
        local Cache = require("core.cache.cache")
        local orig_get_player_favorites = Cache.get_player_favorites
        Cache.get_player_favorites = function() return { {}, "not-a-table", nil } end
        local pf = PlayerFavorites.new(player)
        assert(Helpers.table_count(pf:get_all()) == Constants.settings.MAX_FAVORITE_SLOTS, "All slots should be filled with blank favorites")
        Cache.get_player_favorites = orig_get_player_favorites -- restore
    end)

    it("should validate non-string gps as invalid", function()
        local ok, msg = PlayerFavorites.validate_gps(12345)
        assert(not ok and msg, "Non-string GPS should fail validation")
        ok, msg = PlayerFavorites.validate_gps({})
        assert(not ok and msg, "Table GPS should fail validation")
    end)

    it("should not add blank favorite to player favorites", function()
        local player = make_player(1)
        local pf = PlayerFavorites.new(player)
        local blank = Favorite.get_blank_favorite()
        assert.is_false(pf:add_favorite(blank), "Should not add blank favorite")
    end)

    it("should correctly identify blank favorites in edge cases", function()
        local blank = {gps = BLANK_GPS, text = "", locked = false}
        assert.is_true(Favorite.is_blank_favorite(blank))
        local not_blank = {gps = "123.456.1", text = "foo", locked = false}
        assert.is_false(Favorite.is_blank_favorite(not_blank))
    end)
end)
