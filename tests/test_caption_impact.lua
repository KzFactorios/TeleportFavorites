-- Test file to verify if sprite-button captions affect event handling

---@diagnostic disable: undefined-global

-- This test verifies whether button captions impact the ability to receive click events
-- Run this in-game with /c require("tests.test_caption_impact").run_test()

local GuiBase = require("gui.gui_base")
local GuiUtils = require("core.utils.gui_utils")
local GameHelpers = require("core.utils.game_helpers")

local M = {}

-- Create two test buttons - one with caption, one without
local function setup_test_gui(player)
    -- Clean up any previous test GUI
    for _, child in pairs(player.gui.screen.children) do
        if child.name == "caption_test_frame" then
            child.destroy()
        end
    end
    
    -- Create test frame
    local frame = GuiBase.create_frame(player.gui.screen, "caption_test_frame", "vertical", nil)
    frame.style.size = {300, 200}
    frame.auto_center = true
    
    -- Add heading
    local heading = GuiBase.create_label(frame, "caption_test_heading", "Caption Impact Test", nil)
    heading.style.font = "heading-1"
    
    -- Create flow for buttons
    local button_flow = GuiBase.create_flow(frame, "caption_test_button_flow", "horizontal", nil)
    button_flow.style.horizontal_spacing = 10
    
    -- Create button WITH caption
    local with_caption = GuiBase.create_icon_button(button_flow, "test_with_caption", 
        "utility/questionmark", {"With caption"}, "button")
    with_caption.style.size = {80, 40}
    with_caption.caption = "Caption"
    
    -- Create button WITHOUT caption
    local no_caption = GuiBase.create_icon_button(button_flow, "test_no_caption", 
        "utility/questionmark", {"No caption"}, "button")
    no_caption.style.size = {80, 40}
    no_caption.caption = ""  -- Empty caption
    
    -- Add result labels
    local result_flow = GuiBase.create_flow(frame, "caption_test_result_flow", "vertical", nil)
    GuiBase.create_label(result_flow, "with_caption_result", "With caption: Not clicked", nil)
    GuiBase.create_label(result_flow, "no_caption_result", "No caption: Not clicked", nil)
    
    -- Close button
    local close_button = GuiBase.create_button(frame, "caption_test_close", "Close", nil)
    close_button.style.horizontally_stretchable = true
    
    return frame
end

-- Register event handlers for the test
local function setup_event_handlers()
    script.on_event(defines.events.on_gui_click, function(event)
        local player = game.get_player(event.player_index)
        if not player or not player.valid then return end
        
        local element = event.element
        if not element or not element.valid then return end
        
        -- Handle test button clicks
        if element.name == "test_with_caption" then
            local result_label = player.gui.screen.caption_test_frame.caption_test_result_flow.with_caption_result
            result_label.caption = "With caption: CLICKED!"
            GameHelpers.player_print(player, "Button WITH caption was clicked")
        elseif element.name == "test_no_caption" then
            local result_label = player.gui.screen.caption_test_frame.caption_test_result_flow.no_caption_result
            result_label.caption = "No caption: CLICKED!"
            GameHelpers.player_print(player, "Button WITHOUT caption was clicked")
        elseif element.name == "caption_test_close" then
            player.gui.screen.caption_test_frame.destroy()
        end
    end)
end

-- Entry point for the test
function M.run_test()
    local player = game.player
    if not player or not player.valid then return end
    
    -- Create test GUI
    setup_test_gui(player)
    
    -- Setup event handlers
    setup_event_handlers()
    
    -- Instructions
    GameHelpers.player_print(player, "Test GUI created. Click both buttons to test if caption affects click events.")
end

return M
