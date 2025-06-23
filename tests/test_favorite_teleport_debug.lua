-- Test script for teleport favorites debugging
-- Run this in the Factorio console (`) to test favorite teleportation

local function test_favorite_teleport()
    local player = game.player
    if not player then
        print("No player found")
        return
    end
    
    print("Testing favorite teleportation for player: " .. player.name)
    
    -- Test the teleport function directly using the same logic as the hotkey
    local PlayerFavorites = require("core.favorite.player_favorites")
    local FavoriteUtils = require("core.favorite.favorite")
    local Tag = require("core.tag.tag")
    local Enum = require("prototypes.enums.enum")
    
    local player_favorites = PlayerFavorites.new(player)
    if not player_favorites or not player_favorites.favorites then
        print("No favorites found")
        return
    end
    
    local favorite = player_favorites.favorites[1]
    if not favorite or FavoriteUtils.is_blank_favorite(favorite) then
        print("Favorite slot 1 is empty")
        return
    end
    
    print("Found favorite GPS: " .. tostring(favorite.gps))
    
    local result = Tag.teleport_player_with_messaging(player, favorite.gps, nil)
    local success = result == Enum.ReturnStateEnum.SUCCESS
    
    print("Teleport result: " .. tostring(success))
end

-- Call the test function
test_favorite_teleport()
