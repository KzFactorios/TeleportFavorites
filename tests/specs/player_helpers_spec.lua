---@diagnostic disable: undefined-global
require("test_framework")

describe("PlayerHelpers", function()
    
    before_each(function()
        -- Mock dependencies
        package.loaded["core.utils.safe_helpers"] = {
            is_valid_player = function(player)
                return player and player.valid == true
            end
        }
        
        package.loaded["core.utils.error_handler"] = {
            debug_log = function() end
        }
        
        package.loaded["core.utils.settings_access"] = {
            getPlayerSettings = function(player)
                return {
                    favorites_on = true,
                    show_player_coords = true,
                    show_teleport_history = true
                }
            end
        }
        
        package.loaded["core.utils.small_helpers"] = {
            should_hide_favorites_bar_for_space_platform = function() return false end
        }
        
        -- Mock defines global
        _G.defines = {
            controllers = {
                god = "god",
                spectator = "spectator",
                character = "character"
            }
        }
    end)
    
    it("should load player_helpers without errors", function()
        local success, err = pcall(function()
            require("core.utils.player_helpers")
        end)
        assert(success, "player_helpers should load without errors: " .. tostring(err))
    end)
    
    it("should handle basic functions without errors", function()
        local success, err = pcall(function()
            local PlayerHelpers = require("core.utils.player_helpers")
            local mock_player = {
                valid = true,
                connected = true,
                name = "test_player",
                controller_type = "character",
                print = function() end
            }
            
            -- Test basic functions
            PlayerHelpers.safe_player_print(mock_player, "test")
            PlayerHelpers.are_favorites_enabled(mock_player)
            PlayerHelpers.should_show_coordinates(mock_player)
            PlayerHelpers.should_show_history(mock_player)
            PlayerHelpers.should_hide_favorites_bar(mock_player)
        end)
        assert(success, "player_helpers functions should execute without errors: " .. tostring(err))
    end)
end)
