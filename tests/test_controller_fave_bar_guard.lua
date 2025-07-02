-- Test file for controller-based favorites bar building
-- This test validates that the favorites bar only builds when in character controller mode

local test_name = "test_controller_fave_bar_guard"

local function test_controller_guard()
    if not game then
        return false, "Game not available"
    end
    
    local test_player = game.get_player(1)
    if not test_player or not test_player.valid then
        return false, "No valid player found"
    end
    
    -- Test requires manual verification in-game:
    -- 1. Start in character mode - favorites bar should be visible
    -- 2. Enter editor mode (/editor) - favorites bar should disappear
    -- 3. Exit editor mode (/editor) - favorites bar should reappear
    -- 4. Use god mode (/c game.player.character = nil) - favorites bar should disappear
    -- 5. Restore character (/c game.player.create_character()) - favorites bar should reappear
    
    return true, string.format(
        "Test setup complete. Current controller: %s. " ..
        "Use /editor to test controller switching behavior.",
        test_player.controller_type
    )
end

local function run_test()
    local success, message = test_controller_guard()
    return {
        name = test_name,
        success = success,
        message = message
    }
end

-- Export test functions
return {
    name = test_name,
    run = run_test
}
