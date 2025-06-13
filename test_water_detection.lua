-- Simple water detection test
-- Run this in-game with: /c require("test_water_detection")

local function test_water_detection()
    local player = game.player
    if not player or not player.valid then
        game.print("Error: Player not found")
        return
    end
    
    local surface = player.surface
    local player_pos = player.position
    
    game.print("=== Simple Water Detection Test ===")
    
    -- Get the tile at player position
    local tile = surface.get_tile(math.floor(player_pos.x), math.floor(player_pos.y))
    if tile then
        game.print("Tile name: " .. (tile.name or "unknown"))
        
        -- Test the basic collides_with method
        local success, result = pcall(function() 
            return tile.collides_with("water-tile") 
        end)
        
        if success then
            game.print("collides_with('water-tile'): " .. tostring(result))
            
            if result then
                game.print("*** WATER DETECTED AT CURRENT POSITION ***")
                game.print("If you can still create tags here, there's an issue with the validation flow.")
            else
                game.print("*** NO WATER DETECTED ***")
                game.print("Try standing on water and running this test again.")
            end
        else
            game.print("Error testing collides_with: " .. tostring(result))
        end
        
        -- Also test name-based detection
        local name = tile.name:lower()
        local name_has_water = name:find("water") ~= nil
        game.print("Tile name contains 'water': " .. tostring(name_has_water))
        
    else
        game.print("No tile found at current position")
    end
    
    game.print("=== Test Complete ===")
end

test_water_detection()
