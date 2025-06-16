-- Test suite for tag editor localization

local LocaleUtils = require("core.utils.locale_utils")

-- Mock game object for testing
local mock_game = {
  players = {
    [1] = {
      index = 1,
      name = "test_player",
      locale = "en",
      valid = true
    }
  },
  get_player = function(index)
    return mock_game.players[index]
  end
}

-- Mock global environment
_G.game = mock_game

local function test_tag_editor_error_strings()
  print("Testing tag editor localization strings...")
  
  local player = mock_game.get_player(1)
  
  -- Test all new tag editor error strings
  local test_cases = {
    {key = "tag_text_length_exceeded", params = {"50"}},
    {key = "tag_requires_icon_or_text", params = {}},
    {key = "move_mode_select_destination", params = {}},
    {key = "invalid_location_chosen", params = {}},
    {key = "tag_move_cancelled", params = {}},
    {key = "tag_deletion_forbidden", params = {}}
  }
  
  local all_passed = true
  
  for _, test_case in pairs(test_cases) do
    local result = LocaleUtils.get_error_string(player, test_case.key, test_case.params)
    
    if not result or result == "" then
      print("❌ FAILED: " .. test_case.key .. " - No result returned")
      all_passed = false
    elseif result:find("tf%-error%.") then
      print("❌ FAILED: " .. test_case.key .. " - Returned raw key: " .. result)
      all_passed = false
    else
      print("✅ PASSED: " .. test_case.key .. " - " .. result)
    end
  end
  
  if all_passed then
    print("\n🎉 All tag editor localization tests passed!")
  else
    print("\n⚠️ Some tag editor localization tests failed!")
  end
  
  return all_passed
end

local function test_parameter_substitution()
  print("\nTesting parameter substitution...")
  
  local player = mock_game.get_player(1)
  
  -- Test parameter substitution with tag text length
  local result = LocaleUtils.get_error_string(player, "tag_text_length_exceeded", {"50"})
  
  if result and result:find("50") then
    print("✅ PASSED: Parameter substitution works - " .. result)
    return true
  else
    print("❌ FAILED: Parameter substitution failed - " .. (result or "nil"))
    return false
  end
end

local function test_multi_language_support()
  print("\nTesting multi-language support...")
  
  -- Test German locale
  local german_player = {
    index = 2,
    name = "test_player_de",
    locale = "de",
    valid = true
  }
  mock_game.players[2] = german_player
  
  local result_en = LocaleUtils.get_error_string(mock_game.players[1], "tag_requires_icon_or_text")
  local result_de = LocaleUtils.get_error_string(german_player, "tag_requires_icon_or_text")
  
  if result_en and result_de and result_en ~= result_de then
    print("✅ PASSED: Multi-language support works")
    print("  English: " .. result_en)
    print("  German: " .. result_de)
    return true
  else
    print("❌ FAILED: Multi-language support failed")
    print("  English: " .. (result_en or "nil"))
    print("  German: " .. (result_de or "nil"))
    return false
  end
end

-- Run all tests
local function run_all_tests()
  print("=== Tag Editor Localization Test Suite ===\n")
  
  local results = {
    test_tag_editor_error_strings(),
    test_parameter_substitution(),
    test_multi_language_support()
  }
  
  local passed = 0
  for _, result in pairs(results) do
    if result then passed = passed + 1 end
  end
  
  print(string.format("\n=== Test Results: %d/%d tests passed ===", passed, #results))
  
  if passed == #results then
    print("🎉 All tests passed! Tag editor localization is working correctly.")
  else
    print("⚠️ Some tests failed. Please check the implementation.")
  end
  
  return passed == #results
end

-- Export for external use
return {
  run_all_tests = run_all_tests,
  test_tag_editor_error_strings = test_tag_editor_error_strings,
  test_parameter_substitution = test_parameter_substitution,
  test_multi_language_support = test_multi_language_support
}
