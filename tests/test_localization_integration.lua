
--[[
Integration Test for Localization System

This test demonstrates the complete localization system in action,
including LocaleUtils usage and locale file integration.
]]

local LocaleUtils = require("core.utils.locale_utils")

local TestLocalizationIntegration = {}

--[[
Test LocaleUtils integration with the teleport strategy
]]
function TestLocalizationIntegration.test_teleport_strategy_localization()
    local test_results = {}
    
    -- Mock player for testing
    local mock_player = {
        valid = true,
        name = "TestPlayer",
        get_translated_string = function(self, key_table)
            -- Simulate translated strings from our locale files
            local translations = {
                ["tf-error.driving_teleport_blocked"] = "Are you crazy? Trying to teleport while driving is strictly prohibited.",
                ["tf-error.player_missing"] = "Unable to teleport. Player is missing",
                ["tf-error.validation_failed"] = "Validation failed",
                ["tf-error.position_normalization_failed"] = "Position normalization failed",
                ["tf-error.no_safe_position"] = "No safe landing position found within safety radius",
                ["tf-gui.teleport_success"] = "Teleported successfully!"
            }
            
            return translations[key_table] or key_table
        end
    }
    
    -- Test error string retrieval
    local driving_error = LocaleUtils.get_error_string(mock_player, "driving_teleport_blocked")
    table.insert(test_results, {
        test = "Driving teleport blocked message",
        expected = "Are you crazy? Trying to teleport while driving is strictly prohibited.",
        actual = driving_error,
        passed = driving_error == "Are you crazy? Trying to teleport while driving is strictly prohibited."
    })
    
    -- Test player missing error
    local player_missing_error = LocaleUtils.get_error_string(mock_player, "player_missing")
    table.insert(test_results, {
        test = "Player missing error message",
        expected = "Unable to teleport. Player is missing",
        actual = player_missing_error,
        passed = player_missing_error == "Unable to teleport. Player is missing"
    })
    
    -- Test validation failed error
    local validation_error = LocaleUtils.get_error_string(mock_player, "validation_failed")
    table.insert(test_results, {
        test = "Validation failed error message",
        expected = "Validation failed",
        actual = validation_error,
        passed = validation_error == "Validation failed"
    })
    
    return test_results
end

--[[
Test LocaleUtils integration with favorites management
]]
function TestLocalizationIntegration.test_favorites_localization()
    local test_results = {}
    
    -- Mock player for testing
    local mock_player = {
        valid = true,
        name = "TestPlayer",
        get_translated_string = function(self, key_table)
            local translations = {
                ["tf-error.failed_add_favorite"] = "Failed to add favorite: __1__",
                ["tf-error.failed_remove_favorite"] = "Failed to remove favorite: __1__",
                ["tf-error.failed_reorder_favorite"] = "Failed to reorder favorite: __1__",
                ["tf-error.unknown_error"] = "Unknown error"
            }
            
            return translations[key_table] or key_table
        end
    }
    
    -- Test failed add favorite with parameter
    local add_error = LocaleUtils.get_error_string(mock_player, "failed_add_favorite", {"GPS coordinates invalid"})
    table.insert(test_results, {
        test = "Failed add favorite with parameter",
        expected = "Failed to add favorite: GPS coordinates invalid",
        actual = add_error,
        passed = add_error == "Failed to add favorite: GPS coordinates invalid"
    })
    
    -- Test failed reorder favorite with unknown error fallback
    local reorder_error = LocaleUtils.get_error_string(mock_player, "failed_reorder_favorite", {LocaleUtils.get_error_string(mock_player, "unknown_error")})
    table.insert(test_results, {
        test = "Failed reorder favorite with unknown error fallback",
        expected = "Failed to reorder favorite: Unknown error",
        actual = reorder_error,
        passed = reorder_error == "Failed to reorder favorite: Unknown error"
    })
    
    return test_results
end

--[[
Test LocaleUtils fallback mechanism
]]
function TestLocalizationIntegration.test_fallback_mechanism()
    local test_results = {}
    
    -- Mock player that always returns key (simulating missing translations)
    local mock_player = {
        valid = true,
        name = "TestPlayer",
        get_translated_string = function(self, key_table)
            return key_table -- Always return key (missing translation)
        end
    }
    
    -- Test fallback for critical GUI string
    local confirm_fallback = LocaleUtils.get_gui_string(mock_player, "confirm")
    table.insert(test_results, {
        test = "Confirm button fallback",
        expected = "Confirm",
        actual = confirm_fallback,
        passed = confirm_fallback == "Confirm"
    })
    
    -- Test fallback for critical error string
    local error_fallback = LocaleUtils.get_error_string(mock_player, "driving_teleport_blocked")
    table.insert(test_results, {
        test = "Driving teleport blocked fallback",
        expected = "Are you crazy? Trying to teleport while driving is strictly prohibited.",
        actual = error_fallback,
        passed = error_fallback == "Are you crazy? Trying to teleport while driving is strictly prohibited."
    })
    
    return test_results
end

--[[
Test LocaleUtils with invalid player handling
]]
function TestLocalizationIntegration.test_invalid_player_handling()
    local test_results = {}
    
    -- Test with nil player
    local nil_result = LocaleUtils.get_error_string(nil, "player_missing")
    table.insert(test_results, {
        test = "Handle nil player",
        expected = "Unable to teleport. Player is missing",
        actual = nil_result,
        passed = nil_result == "Unable to teleport. Player is missing"
    })
    
    -- Test with invalid player
    local invalid_player = { valid = false }
    local invalid_result = LocaleUtils.get_error_string(invalid_player, "player_missing")
    table.insert(test_results, {
        test = "Handle invalid player",
        expected = "Unable to teleport. Player is missing",
        actual = invalid_result,
        passed = invalid_result == "Unable to teleport. Player is missing"
    })
    
    return test_results
end

--[[
Run all integration tests
]]
function TestLocalizationIntegration.run_all_tests()
    local all_results = {}
    
    -- Run individual test suites
    local teleport_tests = TestLocalizationIntegration.test_teleport_strategy_localization()
    local favorites_tests = TestLocalizationIntegration.test_favorites_localization()
    local fallback_tests = TestLocalizationIntegration.test_fallback_mechanism()
    local invalid_player_tests = TestLocalizationIntegration.test_invalid_player_handling()
    
    -- Combine all results
    for _, result in ipairs(teleport_tests) do
        table.insert(all_results, result)
    end
    for _, result in ipairs(favorites_tests) do
        table.insert(all_results, result)
    end
    for _, result in ipairs(fallback_tests) do
        table.insert(all_results, result)
    end
    for _, result in ipairs(invalid_player_tests) do
        table.insert(all_results, result)
    end
    
    -- Calculate summary statistics
    local total_tests = #all_results
    local passed_tests = 0
    for _, result in ipairs(all_results) do
        if result.passed then
            passed_tests = passed_tests + 1
        end
    end
    
    return {
        total = total_tests,
        passed = passed_tests,
        failed = total_tests - passed_tests,
        results = all_results
    }
end

--[[
Print integration test results
]]
function TestLocalizationIntegration.print_test_results(results)
    if not results then
        results = TestLocalizationIntegration.run_all_tests()
    end
    
    game.print("=== Localization Integration Test Results ===")
    game.print("Total: " .. results.total .. ", Passed: " .. results.passed .. ", Failed: " .. results.failed)
    game.print("")
    
    for _, result in ipairs(results.results) do
        local status = result.passed and "✓ PASS" or "✗ FAIL"
        game.print(status .. " - " .. result.test)
        if not result.passed then
            game.print("  Expected: " .. tostring(result.expected))
            game.print("  Actual: " .. tostring(result.actual))
        end
    end
    
    game.print("=== End Integration Test Results ===")
end

return TestLocalizationIntegration
