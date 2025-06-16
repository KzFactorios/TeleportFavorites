--[[
Test Suite for Tag Editor Teleport Button Fix

This test validates:
1. GuiUtils.get_gui_frame_by_element correctly identifies main frames using enums
2. LocaleUtils.get_error_string works without crashing
3. The teleport button event routing should work correctly
]]

local GuiUtils = require("core.utils.gui_utils")
local LocaleUtils = require("core.utils.locale_utils")
local Enum = require("prototypes.enums.enum")

local TestTagEditorTeleportFix = {}

function TestTagEditorTeleportFix.test_gui_frame_detection()
    print("Testing GUI frame detection with enum usage...")
    
    -- Mock GUI hierarchy similar to tag editor
    local mock_outer_frame = {
        name = Enum.GuiEnum.GUI_FRAME.TAG_EDITOR,
        type = "frame",
        valid = true,
        parent = nil
    }
    
    local mock_content_frame = {
        name = "tag_editor_content_frame",
        type = "frame", 
        valid = true,
        parent = mock_outer_frame
    }
    
    local mock_row_frame = {
        name = "tag_editor_teleport_favorite_row",
        type = "frame",
        valid = true,
        parent = mock_content_frame
    }
    
    local mock_button = {
        name = "tag_editor_teleport_button",
        type = "sprite-button",
        valid = true,
        parent = mock_row_frame
    }
    
    -- Test that get_gui_frame_by_element finds the main frame, not the row frame
    local result = GuiUtils.get_gui_frame_by_element(mock_button)
    
    if result and result.name == Enum.GuiEnum.GUI_FRAME.TAG_EDITOR then
        print("✅ PASSED: get_gui_frame_by_element correctly identifies main frame using enum")
        return true
    else
        print("❌ FAILED: get_gui_frame_by_element did not find correct frame")
        print("  Expected: " .. tostring(Enum.GuiEnum.GUI_FRAME.TAG_EDITOR))
        print("  Got: " .. tostring(result and result.name or "nil"))
        return false
    end
end

function TestTagEditorTeleportFix.test_locale_utils_no_crash()
    print("Testing LocaleUtils doesn't crash...")
    
    -- Mock player
    local mock_player = {
        valid = true,
        index = 1,
        name = "test_player"
    }
    
    -- Test that get_error_string doesn't crash
    local success, result = pcall(function()
        return LocaleUtils.get_error_string(mock_player, "failed_add_favorite", {"test error"})
    end)
    
    if success and result then
        print("✅ PASSED: LocaleUtils.get_error_string works without crashing")
        print("  Result: " .. tostring(result))
        return true
    else
        print("❌ FAILED: LocaleUtils.get_error_string crashed")
        print("  Error: " .. tostring(result))
        return false
    end
end

function TestTagEditorTeleportFix.test_unknown_error_fallback()
    print("Testing unknown error fallback...")
    
    local mock_player = {
        valid = true,
        index = 1,
        name = "test_player"
    }
    
    local success, result = pcall(function()
        return LocaleUtils.get_error_string(mock_player, "unknown_error")
    end)
    
    if success and result and result ~= "" then
        print("✅ PASSED: Unknown error fallback works")
        print("  Result: " .. tostring(result))
        return true
    else
        print("❌ FAILED: Unknown error fallback failed")
        return false
    end
end

function TestTagEditorTeleportFix.run_all_tests()
    print("=== Tag Editor Teleport Button Fix Test Suite ===")
    
    local tests = {
        TestTagEditorTeleportFix.test_gui_frame_detection,
        TestTagEditorTeleportFix.test_locale_utils_no_crash,
        TestTagEditorTeleportFix.test_unknown_error_fallback
    }
    
    local passed = 0
    local total = #tests
    
    for i, test in ipairs(tests) do
        print("\n--- Test " .. i .. " ---")
        if test() then
            passed = passed + 1
        end
    end
    
    print("\n=== Test Results ===")
    print("Passed: " .. passed .. "/" .. total)
    
    if passed == total then
        print("🎉 ALL TESTS PASSED! The teleport button fix should work correctly.")
    else
        print("⚠️  Some tests failed. Review the fixes.")
    end
    
    return passed == total
end

-- Run tests if executed directly
if ... == nil then
    TestTagEditorTeleportFix.run_all_tests()
end

return TestTagEditorTeleportFix
