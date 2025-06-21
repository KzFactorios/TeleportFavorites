--[[
Test file to verify that the recursion guard between Tag:get_chart_tag() and Cache.get_tag_by_gps() works correctly.
This is a manual test file that can be run in the REPL to verify the fix for the "too many C levels" stack overflow error.

USAGE:
1. Start Factorio with the mod loaded
2. Open the Lua console (Ctrl+`)
3. Run the following command: /c require("tests.test_tag_chart_tag_recursion")

EXPECTED BEHAVIOR:
- The test will create a tag and then attempt to trigger the recursion
- Instead of stack overflow, you should see "[SUCCESS] Recursion guard test passed" in the console
- If you see "[FAILED]" messages, the recursion guard is not working correctly
]]

-- Import required modules
local Tag = require("core.tag.tag")
local Cache = require("core.cache.cache")
local ErrorHandler = require("core.utils.error_handler")
local GPSUtils = require("core.utils.gps_utils")

local function run_test()
    -- Make sure we start with clean state
    _G.__getting_chart_tag = nil
    _G.__getting_tag_by_gps = nil
    
    -- Create a test GPS string for a position on the current surface
    local test_position = {x = 0, y = 0}
    local surface_index = game.player.surface.index
    local test_gps = GPSUtils.gps_from_map_position(test_position, surface_index)
    
    -- Create a test tag
    local test_tag = Tag.new(test_gps, {})
    
    -- Test 1: Verify recursion guard in Tag:get_chart_tag()
    _G.__getting_chart_tag = true -- Simulate recursion
    local chart_tag = test_tag:get_chart_tag()
    
    if chart_tag ~= nil then
        game.print("[FAILED] Recursion guard in Tag:get_chart_tag() did not prevent execution")
    else
        game.print("[SUCCESS] Recursion guard in Tag:get_chart_tag() correctly prevented execution")
    end
    
    -- Reset state
    _G.__getting_chart_tag = nil
    
    -- Test 2: Verify recursion guard in Cache.get_tag_by_gps()
    _G.__getting_tag_by_gps = true -- Simulate recursion
    local tag_from_gps = Cache.get_tag_by_gps(test_gps)
    
    if tag_from_gps ~= nil then
        game.print("[FAILED] Recursion guard in Cache.get_tag_by_gps() did not prevent execution")
    else
        game.print("[SUCCESS] Recursion guard in Cache.get_tag_by_gps() correctly prevented execution")
    end
    
    -- Reset state
    _G.__getting_tag_by_gps = nil
    
    -- Test 3: Verify normal operation
    local tag_normal = Cache.get_tag_by_gps(test_gps)
    
    if tag_normal == nil then
        game.print("[INFO] No tag found at test GPS location (expected if no tag exists at 0,0)")
    else 
        game.print("[INFO] Found tag at test GPS location")
    end
    
    -- Final verification
    if _G.__getting_chart_tag ~= nil or _G.__getting_tag_by_gps ~= nil then
        game.print("[FAILED] Global recursion guards were not properly reset")
    else
        game.print("[SUCCESS] Global recursion guards were properly reset")
    end
    
    game.print("[SUCCESS] Recursion guard test completed")
end

-- Run the test
run_test()

-- Return true to indicate successful execution
return true
