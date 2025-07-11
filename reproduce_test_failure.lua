-- Minimal reproduction of the failing test scenario

package.path = './?.lua;' .. package.path

-- Load test framework to get the exact same environment
require('tests.test_framework')

-- Load and set up exactly like the failing test
require("tests.mocks.factorio_test_env")

-- Mock player factory (must be defined before any use)
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
            if event_type == "favorite_removed" then
                -- ...
            end
        end
    }
}

if not global then
    global = {}
end
if not global.cache then
    global.cache = {}
end

if not storage then
    storage = {}
end

-- Mock Cache
local Cache = require("core.cache.cache")
-- Patch Cache.get_player_favorites to return the correct favorites array for the given player
Cache.get_player_favorites = function(player)
    if not player or not player.valid then return {} end
    if not storage.players then return {} end
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

-- Now require the production observer module, so it uses the test mock
require("core.events.gui_observer")

-- Require PlayerFavorites only after all mocks are set up
local PlayerFavorites = require("core.favorite.player_favorites")

print("=== Reproducing Test Scenario ===")

-- Simulate the before_each reset like the test does
if _G.storage then
    for k in pairs(_G.storage) do _G.storage[k] = nil end
end
if global then
    for k in pairs(global) do global[k] = nil end
end
if game and game.players then
    for k in pairs(game.players) do game.players[k] = nil end
end

-- Reset PlayerFavorites singleton cache like the test does
PlayerFavorites._instances = {}

-- Reset notified
if PlayerFavoritesMocks and PlayerFavoritesMocks.reset_notified then
    PlayerFavoritesMocks.reset_notified()
end

-- Ensure Constants mock is correct
_G.Constants = require("tests.mocks.constants_mock")

print("After resets, testing PlayerFavorites...")

-- Now recreate the test scenario exactly

-- Setup 5 players and a shared tag like the test does
local player_names = {}
for i = 1, 5 do player_names[i] = "Player" .. i end
local tag_id = "tag_sync"
local chart_tag = { id = tag_id, valid = true }
local tag = { gps = tag_id, chart_tag = chart_tag, faved_by_players = {} }

-- Patch Cache.get_tag_by_gps to always return our tag
Cache.get_tag_by_gps = function(player, gps)
    if gps == tag_id then return tag end
    return nil
end

-- Create players and PlayerFavorites exactly like the test
for i, name in ipairs(player_names) do
    game.players[i] = PlayerFavoritesMocks.mock_player(i, name)
end

local pfs = {}
-- Each player adds the same favorite (should update faved_by_players)
for i = 1, 3 do  -- Test just first 3 to minimize output
    print("Creating PlayerFavorites for player", i)
    local player = game.players[i]
    print("  Player", i, "valid:", player and player.valid)
    
    pfs[i] = PlayerFavorites.new(player)
    print("  PlayerFavorites.new returned:", type(pfs[i]))
    
    if type(pfs[i]) == "table" then
        print("  Has add_favorite method:", pfs[i].add_favorite ~= nil)
        if pfs[i].add_favorite then
            local success, result, err = pcall(pfs[i].add_favorite, pfs[i], tag_id)
            if success then
                print("  add_favorite succeeded:", result ~= nil, "error:", err)
            else
                print("  ERROR in add_favorite:", result)
            end
        else
            print("  ERROR: Missing add_favorite method!")
            print("  Available methods:")
            for k, v in pairs(pfs[i]) do
                if type(v) == "function" then
                    print("    ", k)
                end
            end
            local mt = getmetatable(pfs[i])
            print("  Metatable:", mt)
            if mt and mt.__index then
                print("  Metatable.__index:", mt.__index)
                print("  Metatable.__index == PlayerFavorites:", mt.__index == PlayerFavorites)
            end
        end
    else
        print("  ERROR: PlayerFavorites.new returned non-table")
    end
    
    if i == 1 then
        -- Stop at first error to see what's happening
        break
    end
end

print("=== End Test Reproduction ===")
