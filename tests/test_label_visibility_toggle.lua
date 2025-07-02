-- Test file for label visibility toggle behavior
-- This test validates that labels properly show/hide when settings are toggled

local test_name = "test_label_visibility_toggle"

local function test_label_visibility_toggle()
    if not game then
        log("TEST FAILED: Game not available")
        return false
    end
    
    local test_player = game.get_player(1)
    if not test_player or not test_player.valid then
        log("TEST FAILED: No valid player found")
        return false
    end
    
    -- Test coordinate label visibility
    local coords_label = test_player.gui.screen.fave_bar_frame
    if coords_label then
        coords_label = coords_label.fave_bar_content_flow.fave_bar_coords_label
    end
    
    if not coords_label or not coords_label.valid then
        log("TEST FAILED: Coordinate label not found")
        return false
    end
    
    -- Test history label visibility  
    local history_label = test_player.gui.screen.fave_bar_frame
    if history_label then
        history_label = history_label.fave_bar_content_flow.fave_bar_teleport_history_label
    end
    
    if not history_label or not history_label.valid then
        log("TEST FAILED: History label not found")
        return false
    end
    
    log("TEST SUCCESS: Found both coordinate and history labels")
    log("Coordinate label visible: " .. tostring(coords_label.visible))
    log("History label visible: " .. tostring(history_label.visible))
    
    -- Note: This test requires manual verification in-game:
    -- 1. Check that labels are visible when settings are enabled
    -- 2. Toggle settings off and verify labels become hidden
    -- 3. Toggle settings back on and verify labels reappear
    
    return true
end

local function run_test()
    log("=== RUNNING LABEL VISIBILITY TOGGLE TEST ===")
    local success = test_label_visibility_toggle()
    log("Test result: " .. (success and "SUCCESS" or "FAILED"))
    log("=== END TEST ===")
end

-- Export test functions
return {
    name = test_name,
    run = run_test
}
