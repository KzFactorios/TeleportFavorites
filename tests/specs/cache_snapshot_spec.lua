require("test_bootstrap")
require("mocks.factorio_test_env")

local Constants = require("constants")
local PlayerFavoritesMocks = require("tests.mocks.player_favorites_mocks")

describe("Cache snapshot startup path", function()
    local mock_player

    before_each(function()
        storage.players = {}
        storage.surfaces = {}
        game.players = {}
        game.tick = 1

        mock_player = PlayerFavoritesMocks.mock_player(1, "TestPlayer", 1)
        game.players[mock_player.index] = mock_player
    end)

    it("should expose snapshot accessor", function()
        local Cache = require("core.cache.cache")
        assert(type(Cache.get_favorites_render_snapshot) == "function", "expected snapshot accessor")
    end)

    it("should return empty table for invalid player", function()
        local Cache = require("core.cache.cache")
        local snapshot = Cache.get_favorites_render_snapshot(nil, 1, 5)
        assert(type(snapshot) == "table", "snapshot should be a table")
        assert(next(snapshot) == nil, "invalid player should return empty snapshot")
    end)

    it("should return snapshot entries and blank fallback", function()
        local Cache = require("core.cache.cache")
        local player_data = Cache.get_player_data(mock_player)
        player_data.surfaces = player_data.surfaces or {}
        player_data.surfaces[1] = player_data.surfaces[1] or {}
        player_data.surfaces[1].favorites_render_snapshot = {
            {
                gps = "100.200.1",
                locked = true,
                icon = "utility/pin",
                text = "Alpha"
            }
        }

        local snapshot = Cache.get_favorites_render_snapshot(mock_player, 1, 2)
        assert(snapshot[1] ~= nil, "first slot should exist")
        assert(snapshot[1].gps == "100.200.1", "snapshot GPS should be copied")
        assert(snapshot[1].locked == true, "snapshot lock state should be copied")
        assert(snapshot[1].tag and snapshot[1].tag.chart_tag and snapshot[1].tag.chart_tag.valid == true,
            "snapshot entry should include synthetic chart_tag payload")
        assert(snapshot[2] ~= nil, "missing snapshot entry should produce fallback")
        assert(snapshot[2].gps == Constants.settings.BLANK_GPS, "fallback slot should be blank favorite")
    end)
end)
