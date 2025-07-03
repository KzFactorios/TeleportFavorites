
if not _G.storage then _G.storage = {} end
if not _G.settings then
    _G.settings = {}
    function _G.settings.get_player_settings(player)
        return {
            ["show-player-coords"] = { value = true }
        }
    end
end


local FavoriteUtils = require("core.favorite.favorite")
local Constants = require("constants")
local PlayerFavorites = require("core.favorite.player_favorites")

local function mock_player(index, name)
    return {
        index = index or 1,
        name = name or ("Player" .. tostring(index)),
        valid = true,
        surface = { index = 1 },
        mod_settings = {},
        settings = {},
        admin = false,
        render_mode = "game",
        print = function() end,
        play_sound = function() end
    }
end

describe("PlayerFavorites.update_gps_for_all_players (minimal)", function()
    it("should update GPS for all players except the excluded one", function()
        -- Setup two players
        local player1 = mock_player(1, "Guinan")
        local player2 = mock_player(2, "Data")
        _G.game = { players = { [1] = player1, [2] = player2 }, tick = 123456 }
        -- Each gets a favorite with the same GPS
        local pf1 = PlayerFavorites.new(player1)
        local pf2 = PlayerFavorites.new(player2)
        pf1:add_favorite("gps_shared")
        pf2:add_favorite("gps_shared")
        -- Update GPS for all players except player1
        local affected = PlayerFavorites.update_gps_for_all_players("gps_shared", "gps_new", 1)
        assert.is_table(affected)

        assert.equals(#affected, 1)
        assert.equals(affected[1].index, 2)
        assert.equals(pf2.favorites[1].gps, "gps_new")
        assert.equals(pf1.favorites[1].gps, "gps_shared")
    end)
end)
