-- Minimal test to isolate PlayerFavorites issue
require("tests.test_bootstrap")

-- Shared Factorio test environment (globals, settings, etc.)
require("tests.mocks.factorio_test_env")

-- Setup global settings BEFORE loading any modules that depend on it
_G.settings = {
    global = {
        ["tf-max-favorite-slots"] = { value = 10 },
        ["tf-enable-teleport-history"] = { value = true },
        ["tf-max-teleport-history"] = { value = 20 }
    },
    get_player_settings = function(player)
        return { ["show-player-coords"] = { value = true } }
    end
}

-- Mock player factory (must be defined before any use)
local PlayerFavoritesMocks = require("tests.mocks.player_favorites_mocks")

_G.game = {
    players = {
        [1] = PlayerFavoritesMocks.mock_player(1)
    },
    tick = 123456
}

_G.GuiObserver = {
    GuiEventBus = {
        notify = function(event_type, data)
            print("Observer notification:", event_type)
        end
    }
}

-- Force load real Cache module for PlayerFavorites tests
local Cache = require("core.cache.cache")

-- Clear any existing PlayerFavorites from package.loaded
package.loaded["core.favorite.player_favorites"] = nil

-- NOW require PlayerFavorites after all mocks are properly set up
PlayerFavorites = require("core.favorite.player_favorites")

if not storage then
    storage = {}
end

describe("PlayerFavorites Minimal Test", function()
    before_each(function()
        -- Reset storage and PlayerFavorites singleton cache
        _G.storage = { players = {} }
        PlayerFavorites._instances = {}
        game.players[1] = PlayerFavoritesMocks.mock_player(1)
    end)
    
    it("should create PlayerFavorites instance with methods", function()
        print("Test: PlayerFavorites type:", type(PlayerFavorites))
        print("Test: PlayerFavorites.new type:", type(PlayerFavorites.new))
        
        local player = game.players[1]
        print("Test: Player:", player.name, player.index, player.valid)
        
        local pf = PlayerFavorites.new(player)
        print("Test: Instance type:", type(pf))
        print("Test: Instance metatable:", getmetatable(pf))
        
        is_true(pf ~= nil)
        is_true(type(pf.add_favorite) == "function")
        is_true(type(pf.get_favorite_by_slot) == "function")
        
        -- Test add_favorite
        local fav, err = pf:add_favorite("gps:100:200:1")
        print("Test: add_favorite result:", fav, err)
        
        is_true(fav ~= nil)
        is_nil(err)
    end)
end)
