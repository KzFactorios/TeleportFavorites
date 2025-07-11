-- Test just PlayerFavorites loading in test environment
print("=== Testing PlayerFavorites in Test Environment ===")

-- Load test framework environment
require("tests.test_framework")

-- Mock PlayerFavoritesMocks
local PlayerFavoritesMocks = require("tests.mocks.player_favorites_mocks")

-- Setup basic environment
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

_G.game = {
    players = {
        [1] = PlayerFavoritesMocks.mock_player(1)
    },
    tick = 123456
}

_G.storage = { players = {} }

_G.GuiObserver = {
    GuiEventBus = {
        notify = function(event_type, data)
            print("Observer notification:", event_type)
        end
    }
}

-- Clear cache and load real Cache
package.loaded["core.cache.cache"] = nil
local Cache = require("core.cache.cache")

-- Patch Cache
Cache.get_player_favorites = function(player)
    if not player or not player.valid then return {} end
    if not storage.players then return {} end
    local pdata = storage.players[player.index]
    if not pdata or not pdata.surfaces then return {} end
    local sdata = pdata.surfaces[player.surface.index]
    if not sdata or not sdata.favorites then return {} end
    return sdata.favorites
end

Cache.get_tag_by_gps = function(player, gps)
    return nil
end

-- Clear and load PlayerFavorites
package.loaded["core.favorite.player_favorites"] = nil

print("Attempting to require PlayerFavorites...")
local success, result = pcall(require, "core.favorite.player_favorites")

if success then
    local PlayerFavorites = result
    print("SUCCESS - PlayerFavorites loaded")
    print("Type:", type(PlayerFavorites))
    print("new method:", type(PlayerFavorites.new))
    print("add_favorite method:", type(PlayerFavorites.add_favorite))
    print("__index:", PlayerFavorites.__index)
    
    -- Test object creation
    local player = _G.game.players[1]
    local pf = PlayerFavorites.new(player)
    print("Created instance type:", type(pf))
    print("Instance add_favorite:", type(pf.add_favorite))
else
    print("FAILED to require PlayerFavorites:", result)
end

print("=== Test Complete ===")
