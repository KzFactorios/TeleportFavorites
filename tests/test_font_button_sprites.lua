-- Test script to verify data viewer font button sprites are working
-- This script tests sprite validation and button creation

local test_font_button_sprites = {}

function test_font_button_sprites.test_sprite_validation()
    game.print("=== Testing Sprite Validation ===")
    
    -- Mock the enhanced validate_sprite function
    local function validate_sprite(sprite_path)
        if not sprite_path or sprite_path == "" then return false end
        
        -- Check for common vanilla sprites
        local common_sprites = {
            "utility/add", "utility/remove", "utility/close", "utility/refresh",
            "utility/arrow-up", "utility/arrow-down", "utility/arrow-left", "utility/arrow-right",
            "utility/questionmark", "utility/check_mark", "utility/warning_icon",
            "utility/trash", "utility/copy", "utility/edit", "utility/enter",
            "utility/confirm_slot", "utility/reset", "utility/danger_icon", "utility/info",
            "utility/export_slot", "utility/import_slot", "utility/list_view",
            "utility/lock", "utility/pin", "utility/play", "utility/search_icon", "utility/settings"
        }
        
        for _, known_sprite in ipairs(common_sprites) do
            if sprite_path == known_sprite then return true end
        end
        
        -- Check for custom TeleportFavorites sprites
        local tf_custom_sprites = {
            "tf_hint_arrow_up", "tf_hint_arrow_down", "tf_hint_arrow_left", "tf_hint_arrow_right",
            "tf_star_disabled", "move_tag_icon", "logo_36", "logo_144"
        }
        
        for _, known_sprite in ipairs(tf_custom_sprites) do
            if sprite_path == known_sprite then return true end
        end
        
        return false
    end
    
    -- Test the specific sprites used in data viewer
    local test_sprites = {
        "tf_hint_arrow_up",
        "tf_hint_arrow_down", 
        "utility/refresh",
        "utility/questionmark"
    }
    
    for _, sprite in ipairs(test_sprites) do
        local is_valid = validate_sprite(sprite)
        game.print(string.format("  %s: %s", sprite, is_valid and "VALID" or "INVALID"))
    end
    
    game.print("=== Sprite Validation Test Complete ===")
end

function test_font_button_sprites.test_actual_button_creation(player)
    if not player or not player.valid then
        game.print("ERROR: Invalid player for button creation test")
        return false
    end
    
    game.print("=== Testing Actual Button Creation ===")
    
    -- Create a temporary frame to test button creation
    local test_frame = player.gui.screen.add{
        type = "frame",
        name = "temp_sprite_test_frame",
        caption = "Sprite Test"
    }
    
    local test_flow = test_frame.add{
        type = "flow", 
        direction = "horizontal"
    }
    
    -- Test creating buttons with the same sprites as data viewer
    local sprites_to_test = {
        {name = "font_down", sprite = "tf_hint_arrow_down"},
        {name = "font_up", sprite = "tf_hint_arrow_up"},
        {name = "refresh", sprite = "utility/refresh"}
    }
    
    local results = {}
    
    for _, test_sprite in ipairs(sprites_to_test) do
        local button = test_flow.add{
            type = "sprite-button",
            name = "test_" .. test_sprite.name,
            sprite = test_sprite.sprite
        }
        
        results[test_sprite.name] = {
            created = button ~= nil,
            valid = button and button.valid,
            sprite_set = button and button.sprite or "none",
            sprite_expected = test_sprite.sprite
        }
        
        game.print(string.format("  %s: created=%s, sprite='%s'", 
            test_sprite.name, 
            tostring(results[test_sprite.name].created),
            results[test_sprite.name].sprite_set))
    end
    
    -- Clean up test frame
    test_frame.destroy()
    
    game.print("=== Button Creation Test Complete ===")
    return results
end

function test_font_button_sprites.register_commands()
    commands.add_command("test-sprite-validation", "Test sprite validation logic", function(command)
        test_font_button_sprites.test_sprite_validation()
    end)
    
    commands.add_command("test-button-sprites", "Test actual button sprite creation", function(command)
        local player = game.get_player(command.player_index)
        if player then
            test_font_button_sprites.test_actual_button_creation(player)
        else
            game.print("ERROR: Command must be run by a player")
        end
    end)
end

return test_font_button_sprites
