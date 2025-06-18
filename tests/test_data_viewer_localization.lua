-- Test script to verify data viewer tab button localization
-- This script should be run in-game to test the actual localization

local test_data_viewer_localization = {}

function test_data_viewer_localization.run_test(player)
    if not player or not player.valid then
        game.print("ERROR: Invalid player for localization test")
        return false
    end
    
    game.print("=== Data Viewer Localization Test ===")
    
    -- Test the locale keys that should be defined
    local test_keys = {
        "tf-gui.tab_player_data",
        "tf-gui.tab_surface_data", 
        "tf-gui.tab_lookups",
        "tf-gui.tab_all_data",
        "tf-gui.data_viewer_title",
        "tf-gui.font_minus_tooltip",
        "tf-gui.font_plus_tooltip",
        "tf-gui.refresh_tooltip"
    }
    
    local all_passed = true
    
    for _, key in ipairs(test_keys) do
        -- Test LocalisedString format
        local localized_string = {key}
        local test_result = "PASS"
        
        -- Create a temporary label to test if the localization works
        local temp_frame = player.gui.screen.add{type = "frame", name = "temp_localization_test"}
        local temp_label = temp_frame.add{type = "label", name = "temp_label", caption = localized_string}
        
        -- Check if the caption shows a localization key (indicating failure) or actual text
        local caption_text = tostring(temp_label.caption)
        if caption_text:find("tf%-gui%.") then
            test_result = "FAIL - showing localization key"
            all_passed = false
        end
        
        game.print(string.format("  %s: %s (displays as: %s)", key, test_result, caption_text))
        
        -- Clean up
        temp_frame.destroy()
    end
    
    game.print(string.format("=== Test Result: %s ===", all_passed and "PASSED" or "FAILED"))
    return all_passed
end

-- Command to run the test
function test_data_viewer_localization.register_command()
    commands.add_command("test-dv-localization", "Test data viewer localization", function(command)
        local player = game.get_player(command.player_index)
        if player then
            test_data_viewer_localization.run_test(player)
        else
            game.print("ERROR: Command must be run by a player")
        end
    end)
end

return test_data_viewer_localization
