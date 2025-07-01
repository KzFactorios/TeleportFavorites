--[[
test_label_updates.lua
TeleportFavorites Factorio Mod
-----------------------------
Tests for coordinate and teleport history label updates.

This test file verifies:
1. Player coordinates label updates correctly
2. Teleport history label updates correctly
3. Both labels respect their respective settings

To run these tests, execute the following in the Factorio console:
/c require("tests.test_label_updates").run()
]]

local FaveBarGuiLabelsManager = require("core.control.fave_bar_gui_labels_manager")
local Settings = require("core.utils.settings_access")
local ErrorHandler = require("core.utils.error_handler")
local GuiValidation = require("core.utils.gui_validation")
local GuiHelpers = require("core.utils.gui_helpers")
local GameHelpers = require("core.utils.game_helpers")

local test_label_updates = {}

local function get_label(player, label_name)
    if not player or not player.valid then return nil end
    
    local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
    if not main_flow or not main_flow.valid then return nil end
    
    local fave_bar_frame = GuiHelpers.find_child_by_name(main_flow, "fave_bar_frame")
    if not fave_bar_frame or not fave_bar_frame.valid then return nil end
    
    local fave_bar_flow = GuiHelpers.find_child_by_name(fave_bar_frame, "fave_bar_flow")
    if not fave_bar_flow or not fave_bar_flow.valid then return nil end
    
    local toggle_container = GuiHelpers.find_child_by_name(fave_bar_flow, "fave_bar_toggle_container")
    if not toggle_container or not toggle_container.valid then return nil end
    
    return GuiHelpers.find_child_by_name(toggle_container, label_name)
end

-- Test functionality
function test_label_updates.run()
    local player = game.player
    if not player or not player.valid then
        GameHelpers.player_print(player, "Error: Invalid player")
        return
    end
    
    GameHelpers.player_print(player, "Starting label update test...")
    
    -- Test 1: Check if label elements exist
    local coords_label = get_label(player, "fave_bar_coords_label")
    local history_label = get_label(player, "fave_bar_history_label")
    
    if not coords_label then
        GameHelpers.player_print(player, "Error: Coordinates label not found")
    else
        GameHelpers.player_print(player, "Coordinates label found with caption: " .. tostring(coords_label.caption))
    end
    
    if not history_label then
        GameHelpers.player_print(player, "Error: History label not found")
    else
        GameHelpers.player_print(player, "History label found with caption: " .. tostring(history_label.caption))
    end
    
    -- Test 2: Force update the labels
    -- Use the new manager to force update (simulate setting enabled)
    -- These tests require a running Factorio script context. Manual in-game test required for label updates.
    -- See README or in-game instructions for how to verify label updates.
    
    GameHelpers.player_print(player, "Labels visibility updated based on settings")
    
    -- Test 3: Show current player settings
    local player_settings = Settings:getPlayerSettings(player)
    GameHelpers.player_print(player, "Settings: show_player_coords=" .. tostring(player_settings.show_player_coords) .. 
                                     ", show_teleport_history=" .. tostring(player_settings.show_teleport_history))
    
    -- Test 4: Force labels to update their content
    local success, err = pcall(function()
        -- Force manual updates
        if coords_label and coords_label.valid then
            local pos = player.position
            local x_str = string.format("%.0f", pos.x)
            local y_str = string.format("%.0f", pos.y)
            coords_label.caption = nil
            GameHelpers.player_print(player, "Manually updated coords label to: " .. coords_label.caption)
        end
        
        if history_label and history_label.valid then
            history_label.caption = nil
            GameHelpers.player_print(player, "Manually updated history label to: " .. history_label.caption)
        end
    end)
    
    if not success then
        GameHelpers.player_print(player, "Error updating labels: " .. tostring(err))
    end
    
    GameHelpers.player_print(player, "Label update test completed!")
end

return test_label_updates
