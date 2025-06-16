
--[[
Test Suite for LocaleUtils Module

This test validates the LocaleUtils functionality including:
- String retrieval from different categories
- Parameter substitution
- Fallback handling for missing translations
- Debug mode functionality
- Translation validation
]]

local LocaleUtils = require("core.utils.locale_utils")

local TestLocaleUtils = {}

--[[
Test basic string retrieval functionality
]]
function TestLocaleUtils.test_basic_string_retrieval()
    local test_results = {}
    
    -- Mock player object for testing
    local mock_player = {
        valid = true,
        get_translated_string = function(self, key_table)
            -- Simulate successful translation
            if key_table == "tf-gui.confirm" then
                return "Confirm"
            elseif key_table == "tf-error.driving_teleport_blocked" then
                return "Are you crazy? Trying to teleport while driving is strictly prohibited."
            end
            -- Return key if not found (Factorio behavior)
            return key_table
        end
    }
    
    -- Test GUI string retrieval
    local gui_string = LocaleUtils.get_gui_string(mock_player, "confirm")
    table.insert(test_results, {
        test = "GUI string retrieval",
        expected = "Confirm",
        actual = gui_string,
        passed = gui_string == "Confirm"
    })
    
    -- Test error string retrieval
    local error_string = LocaleUtils.get_error_string(mock_player, "driving_teleport_blocked")
    table.insert(test_results, {
        test = "Error string retrieval",
        expected = "Are you crazy? Trying to teleport while driving is strictly prohibited.",
        actual = error_string,
        passed = error_string == "Are you crazy? Trying to teleport while driving is strictly prohibited."
    })
    
    return test_results
end

--[[
Test parameter substitution functionality
]]
function TestLocaleUtils.test_parameter_substitution()
    local test_results = {}
    
    -- Test numbered parameter substitution
    local text_with_params = "Player __1__ teleported to __2__"
    local substituted = LocaleUtils.substitute_parameters(text_with_params, {"Alice", "Base"})
    table.insert(test_results, {
        test = "Numbered parameter substitution",
        expected = "Player Alice teleported to Base",
        actual = substituted,
        passed = substituted == "Player Alice teleported to Base"
    })
    
    -- Test named parameter substitution
    local text_with_named = "Owner: __name__, Position: __pos__"
    local substituted_named = LocaleUtils.substitute_parameters(text_with_named, {name = "Bob", pos = "1000, 2000"})
    table.insert(test_results, {
        test = "Named parameter substitution",
        expected = "Owner: Bob, Position: 1000, 2000",
        actual = substituted_named,
        passed = substituted_named == "Owner: Bob, Position: 1000, 2000"
    })
    
    return test_results
end

--[[
Test fallback handling for missing translations
]]
function TestLocaleUtils.test_fallback_handling()
    local test_results = {}
    
    -- Mock player that returns key for missing translations
    local mock_player = {
        valid = true,
        get_translated_string = function(self, key_table)
            -- Always return the key (simulating missing translation)
            return key_table
        end
    }
    
    -- Test fallback for known GUI string
    local fallback_string = LocaleUtils.get_gui_string(mock_player, "confirm")
    table.insert(test_results, {
        test = "Fallback for GUI confirm",
        expected = "Confirm",
        actual = fallback_string,
        passed = fallback_string == "Confirm"
    })
    
    -- Test fallback for unknown string
    local unknown_fallback = LocaleUtils.get_gui_string(mock_player, "unknown_key")
    table.insert(test_results, {
        test = "Fallback for unknown key",
        expected = "[gui:unknown_key]",
        actual = unknown_fallback,
        passed = unknown_fallback == "[gui:unknown_key]"
    })
    
    return test_results
end

--[[
Test invalid player handling
]]
function TestLocaleUtils.test_invalid_player_handling()
    local test_results = {}
    
    -- Test with nil player
    local nil_player_result = LocaleUtils.get_gui_string(nil, "confirm")
    table.insert(test_results, {
        test = "Nil player handling",
        expected = "Confirm",
        actual = nil_player_result,
        passed = nil_player_result == "Confirm"
    })
    
    -- Test with invalid player
    local invalid_player = { valid = false }
    local invalid_player_result = LocaleUtils.get_gui_string(invalid_player, "confirm")
    table.insert(test_results, {
        test = "Invalid player handling",
        expected = "Confirm",
        actual = invalid_player_result,
        passed = invalid_player_result == "Confirm"
    })
    
    return test_results
end

--[[
Test category validation
]]
function TestLocaleUtils.test_category_validation()
    local test_results = {}
    
    -- Mock player
    local mock_player = {
        valid = true,
        get_translated_string = function(self, key_table)
            return key_table
        end
    }
    
    -- Test unknown category
    local unknown_category_result = LocaleUtils.get_string(mock_player, "unknown_category", "test_key")
    table.insert(test_results, {
        test = "Unknown category handling",
        expected = "test_key",
        actual = unknown_category_result,
        passed = unknown_category_result == "test_key"
    })
    
    -- Test valid categories
    local categories = LocaleUtils.get_categories()
    local expected_categories = {"gui", "error", "command", "handler", "setting_name", "setting_desc"}
    local categories_match = true
    for _, expected in ipairs(expected_categories) do
        local found = false
        for _, actual in ipairs(categories) do
            if actual == expected then
                found = true
                break
            end
        end
        if not found then
            categories_match = false
            break
        end
    end
    
    table.insert(test_results, {
        test = "Get categories",
        expected = table.concat(expected_categories, ", "),
        actual = table.concat(categories, ", "),
        passed = categories_match
    })
    
    return test_results
end

--[[
Run all tests and return comprehensive results
]]
function TestLocaleUtils.run_all_tests()
    local all_results = {}
    
    -- Run individual test suites
    local basic_tests = TestLocaleUtils.test_basic_string_retrieval()
    local param_tests = TestLocaleUtils.test_parameter_substitution()
    local fallback_tests = TestLocaleUtils.test_fallback_handling()
    local invalid_player_tests = TestLocaleUtils.test_invalid_player_handling()
    local category_tests = TestLocaleUtils.test_category_validation()
    
    -- Combine all results
    for _, result in ipairs(basic_tests) do
        table.insert(all_results, result)
    end
    for _, result in ipairs(param_tests) do
        table.insert(all_results, result)
    end
    for _, result in ipairs(fallback_tests) do
        table.insert(all_results, result)
    end
    for _, result in ipairs(invalid_player_tests) do
        table.insert(all_results, result)
    end
    for _, result in ipairs(category_tests) do
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
Print test results in a readable format
]]
function TestLocaleUtils.print_test_results(results)
    if not results then
        results = TestLocaleUtils.run_all_tests()
    end
    
    game.print("=== LocaleUtils Test Results ===")
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
    
    game.print("=== End Test Results ===")
end

return TestLocaleUtils
