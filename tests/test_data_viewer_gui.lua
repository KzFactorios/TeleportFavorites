-- Test script for data viewer GUI functionality
-- This script validates the data viewer's core functionality

local data_viewer = require("gui.data_viewer.data_viewer")
local control_data_viewer = require("core.control.control_data_viewer")
local Cache = require("core.cache.cache")
local GuiUtils = require("core.utils.gui_utils")

local test_data_viewer = {}

function test_data_viewer.test_sprite_validation()
    local sprites_to_test = {
        "utility/arrow-up",
        "utility/arrow-down", 
        "utility/refresh"
    }
    
    for _, sprite in ipairs(sprites_to_test) do
        local is_valid = GuiUtils.validate_sprite(sprite)
        log(string.format("[TEST] Sprite '%s': %s", sprite, is_valid and "VALID" or "INVALID"))
    end
end

function test_data_viewer.test_data_loading(player)
    if not player or not player.valid then
        log("[TEST] Invalid player provided")
        return false
    end
      -- Test data loading for each tab
    local tabs = {"player_data", "surface_data", "lookup", "all_data"}
    
    for _, tab in ipairs(tabs) do
        local state = control_data_viewer.load_tab_data(player, tab, 12)
        local has_data = state and state.data and type(state.data) == "table"
        log(string.format("[TEST] Tab '%s' data loading: %s", tab, has_data and "SUCCESS" or "FAILED"))
        
        if has_data then
            local data_count = 0
            for _ in pairs(state.data) do
                data_count = data_count + 1
            end
            log(string.format("[TEST] Tab '%s' has %d data entries", tab, data_count))
        end
    end
    
    return true
end

function test_data_viewer.test_gui_creation(player)
    if not player or not player.valid then
        log("[TEST] Invalid player provided")
        return false
    end
    
    -- Test data viewer GUI creation
    local main_flow = GuiUtils.get_or_create_gui_flow_from_gui_top(player)
    if not main_flow then
        log("[TEST] Failed to get main GUI flow")
        return false
    end
    
    -- Clear any existing data viewer
    GuiUtils.safe_destroy_frame(main_flow, "data_viewer_frame")
    
    -- Test building the data viewer
    local pdata = Cache.get_player_data(player)
    pdata.data_viewer_settings = pdata.data_viewer_settings or {}
    local active_tab = pdata.data_viewer_settings.active_tab or "player_data"
    local font_size = pdata.data_viewer_settings.font_size or 12
    
    local state = control_data_viewer.load_tab_data(player, active_tab, font_size)
    if not state then
        log("[TEST] Failed to load tab data")
        return false
    end
    
    local frame = data_viewer.build(player, main_flow, state)
    local success = frame and frame.valid
    
    log(string.format("[TEST] Data viewer GUI creation: %s", success and "SUCCESS" or "FAILED"))
    
    if success then
        -- Test that action buttons are present
        local inner_flow = GuiUtils.find_child_by_name(frame, "data_viewer_inner_flow")
        if inner_flow then
            local tabs_flow = GuiUtils.find_child_by_name(inner_flow, "data_viewer_tabs_flow")
            if tabs_flow then
                local font_up_btn = GuiUtils.find_child_by_name(tabs_flow, "data_viewer_actions_font_up_btn")
                local font_down_btn = GuiUtils.find_child_by_name(tabs_flow, "data_viewer_actions_font_down_btn")
                local refresh_btn = GuiUtils.find_child_by_name(tabs_flow, "data_viewer_tab_actions_refresh_data_btn")
                
                log(string.format("[TEST] Font up button: %s", font_up_btn and "FOUND" or "MISSING"))
                log(string.format("[TEST] Font down button: %s", font_down_btn and "FOUND" or "MISSING"))
                log(string.format("[TEST] Refresh button: %s", refresh_btn and "FOUND" or "MISSING"))
                
                -- Test button sprites
                if font_up_btn and font_up_btn.sprite then
                    log(string.format("[TEST] Font up button sprite: %s", font_up_btn.sprite))
                end
                if font_down_btn and font_down_btn.sprite then
                    log(string.format("[TEST] Font down button sprite: %s", font_down_btn.sprite))
                end
                if refresh_btn and refresh_btn.sprite then
                    log(string.format("[TEST] Refresh button sprite: %s", refresh_btn.sprite))
                end
            end
        end
    end
    
    return success
end

-- Test data viewer localization
function test_data_viewer.test_localization(player)
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
    
    game.print(string.format("=== Localization Test Result: %s ===", all_passed and "PASSED" or "FAILED"))
    return all_passed
end

function test_data_viewer.run_all_tests(player)
    log("[TEST] Starting data viewer tests...")
    
    test_data_viewer.test_sprite_validation()
    test_data_viewer.test_data_loading(player)
    test_data_viewer.test_gui_creation(player)
    test_data_viewer.test_localization(player)
    
    log("[TEST] Data viewer tests completed")
end

return test_data_viewer
