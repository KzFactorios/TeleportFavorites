---@diagnostic disable: undefined-global
require("test_framework")

describe("PlayerHelpers", function()
    
    before_each(function()
        -- Use shared mock setup for consistency
        local SharedMocks = require("tests.mocks.shared_mocks")
        SharedMocks.setup_standard_test_env()
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
