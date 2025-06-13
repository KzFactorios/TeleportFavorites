---@diagnostic disable: undefined-global
--[[
position_validation_test.lua
TeleportFavorites Factorio Mod
-----------------------------
This is a test script for verifying the position validation functionality.
Run this in-game using the Lua console with:

/c require("tests/position_validation_test")

Make sure you are near water or space tiles for proper testing.
]]

local ErrorHandler = require("core.utils.error_handler")
local Helpers = require("core.utils.helpers_suite")
local GPSCore = require("core.utils.gps_core")
local PositionValidator = require("core.utils.position_validator")
local gps_helpers = require("core.utils.gps_helpers")
local Cache = require("core.cache.cache")

-- Enable debug logging
ErrorHandler.set_log_level(ErrorHandler.LOG_LEVELS.DEBUG)

local function run_test()
    local player = game.player
    if not player or not player.valid then
        game.print("Error: Player not found")
        return
    end
    
    game.print("Starting position validation test...")
    
    -- Step 1: Get player's current position
    local player_pos = {
        x = math.floor(player.position.x),
        y = math.floor(player.position.y)
    }
    local player_gps = GPSCore.gps_from_map_position(player_pos, player.surface.index)
    game.print("Current position: " .. player_gps)
    
    -- Step 2: Check if current position is valid
    local is_valid = PositionValidator.is_valid_tag_position(player, player_pos, false)
    game.print("Current position is " .. (is_valid and "valid" or "invalid") .. " for tagging")
    
    -- Step 3: Try to find nearby water or space
    local found_invalid = false
    local invalid_pos = nil
    local search_radius = 20
    
    game.print("Searching for invalid positions nearby...")
    for dx = -search_radius, search_radius do
        for dy = -search_radius, search_radius do
            local test_pos = {
                x = player_pos.x + dx,
                y = player_pos.y + dy
            }
            
            local is_water = Helpers.is_water_tile(player.surface, test_pos)
            local is_space = Helpers.is_space_tile(player.surface, test_pos)
            
            if is_water or is_space then
                invalid_pos = test_pos
                found_invalid = true
                game.print("Found " .. (is_water and "water" or "space") .. " at: " .. 
                    GPSCore.gps_from_map_position(test_pos, player.surface.index))
                break
            end
        end
        if found_invalid then break end
    end
    
    if not found_invalid then
        game.print("No invalid positions found nearby. Test skipped.")
        return
    end
    
    -- Step 4: Test finding valid position near invalid one
    local valid_pos = PositionValidator.find_valid_position(player, invalid_pos, search_radius)
    if valid_pos then
        game.print("Found valid position near invalid one: " .. 
            GPSCore.gps_from_map_position(valid_pos, player.surface.index))
    else
        game.print("Failed to find valid position nearby")
    end
    
    -- Step 5: Test position normalization with invalid position
    local invalid_gps = GPSCore.gps_from_map_position(invalid_pos, player.surface.index)
    local norm_position = gps_helpers.normalize_landing_position_with_cache(player, invalid_gps, Cache)
    
    if norm_position then
        game.print("Normalized position from invalid GPS: " .. 
            GPSCore.gps_from_map_position(norm_position, player.surface.index))
    else
        game.print("Failed to normalize invalid position")
    end
    
    game.print("Position validation test completed")
end

-- Run the test
run_test()

return true
