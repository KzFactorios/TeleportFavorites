-- Simple debug script to check PlayerFavorites module
print("=== Testing PlayerFavorites module ===")

-- Set up minimal environment
_G.storage = {}

-- Load dependencies first
local Constants = require("constants")
print("Constants loaded:", Constants and "OK" or "FAIL")

local FavoriteUtils = require("core.favorite.favorite")
print("FavoriteUtils loaded:", FavoriteUtils and "OK" or "FAIL")

-- Create mock player
local mock_player = {
    valid = true,
    index = 1,
    surface = { index = 1 }
}

-- Load PlayerFavorites
local PlayerFavorites = require("core.favorite.player_favorites")
print("PlayerFavorites type:", type(PlayerFavorites))
print("PlayerFavorites.new type:", type(PlayerFavorites.new))

-- Try to create an instance
local ok, result = pcall(function()
    return PlayerFavorites.new(mock_player)
end)

if ok then
    print("PlayerFavorites.new() success!")
    print("Result type:", type(result))
    if result then
        print("Result.add_favorite:", type(result.add_favorite))
        print("Result.favorites:", type(result.favorites))
        if result.favorites then
            print("Favorites length:", #result.favorites)
        end
    end
else
    print("PlayerFavorites.new() failed:", result)
end
