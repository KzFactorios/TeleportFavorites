-- Debug script to mimic the exact test environment setup

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

-- Mock player factory
local PlayerFavoritesMocks = require("tests.mocks.player_favorites_mocks")

local notified = {}
_G.game = {
    players = {
        [1] = PlayerFavoritesMocks.mock_player(1)
    },
    tick = 123456
}
local function reset_notified()
    for k in pairs(notified) do
        notified[k] = nil
    end
end
_G.GuiObserver = {
    GuiEventBus = {
        notify = function(event_type, data)
            notified[event_type] = data
        end
    }
}

-- Force load real Cache module for PlayerFavorites tests
local Cache = require("core.cache.cache")

-- Mock Cache functions BEFORE requiring PlayerFavorites
function Cache.get_player_favorites(player)
    if not player or not player.valid then return {} end
    local pdata = storage.players[player.index]
    if not pdata or not pdata.surfaces then return {} end
    local sdata = pdata.surfaces[player.surface.index]
    if not sdata or not sdata.favorites then return {} end
    return sdata.favorites
end

if not Cache.get_tag_by_gps then
    function Cache.get_tag_by_gps(player, gps)
        return nil
    end
end

-- Clear any existing PlayerFavorites from package.loaded
package.loaded["core.favorite.player_favorites"] = nil

-- NOW require PlayerFavorites after all mocks are properly set up
PlayerFavorites = require("core.favorite.player_favorites")

if not global then
    global = {}
end

if not storage then
    storage = {}
end

-- Now require the production observer module, so it uses the test mock
require("core.events.gui_observer")

print("=== Testing PlayerFavorites in same environment as tests ===")

-- CRITICAL: PlayerFavorites needs the REAL Cache module, not the mock
package.loaded["core.cache.cache"] = nil
package.loaded["core.favorite.player_favorites"] = nil

-- Re-require Cache first
Cache = require("core.cache.cache")

-- Recreate player mocks after clearing
_G.game = {
    players = {
        [1] = PlayerFavoritesMocks.mock_player(1)
    },
    tick = 123456
}

-- Reset storage and reset PlayerFavorites singleton cache
_G.storage = { players = {} }
PlayerFavorites = require("core.favorite.player_favorites")
PlayerFavorites._instances = {}

-- Ensure Constants mock is always correct
_G.Constants = require("tests.mocks.constants_mock")

print("PlayerFavorites type after setup:", type(PlayerFavorites))
print("PlayerFavorites methods:")
for k, v in pairs(PlayerFavorites) do
    print("  ", k, type(v))
end

local player = game.players[1]
print("Player:", player.name, player.index, player.valid)

print("Creating PlayerFavorites instance...")
local success, result = pcall(function()
    return PlayerFavorites.new(player)
end)

if success then
    print("Instance created:", type(result))
    print("Instance metatable:", getmetatable(result))
    print("Instance methods:")
    if getmetatable(result) and getmetatable(result).__index then
        for k, v in pairs(getmetatable(result).__index) do
            print("  ", k, type(v))
        end
    end
    
    print("Testing add_favorite method...")
    if result.add_favorite then
        local success2, fav, err = pcall(function()
            return result:add_favorite("gps:100:200:1")
        end)
        
        if success2 then
            print("add_favorite successful:", fav ~= nil, err)
        else
            print("add_favorite failed:", fav)
        end
    else
        print("add_favorite method missing!")
    end
else
    print("Failed to create instance:", result)
end
