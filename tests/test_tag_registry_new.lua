--[[
Test file for the new TagRegistry architecture.
This test verifies that the circular dependencies between Tag, Cache, and Lookups
have been resolved through the new TagRegistry module.

USAGE:
1. Start Factorio with the mod loaded
2. Open the Lua console (Ctrl+`)
3. Run the following command: /c require("tests.test_tag_registry_new").run_test()
]]

-- Import required modules
local Tag = require("core.tag.tag")
local Cache = require("core.cache.cache")
local TagRegistry = require("core.tag.tag_registry")
local ErrorHandler = require("core.utils.error_handler")
local GPSUtils = require("core.utils.gps_utils")

local function run_test()
    game.print("[TEST] Starting TagRegistry Architecture Test")
    
    -- Create a test GPS string for a position on the current surface
    local test_position = {x = 0, y = 0}
    local surface_index = game.player.surface.index
    local test_gps = GPSUtils.gps_from_map_position(test_position, surface_index)
    
    -- Test 1: Create a tag
    game.print("[TEST] 1. Creating new Tag object")
    local test_tag = Tag.new(test_gps, {})
    
    -- Test 2: Verify Tag:get_chart_tag() works without global guards
    game.print("[TEST] 2. Testing Tag:get_chart_tag()")
    local chart_tag = test_tag:get_chart_tag()
    game.print("[INFO] Tag:get_chart_tag() returned: " .. (chart_tag and "chart_tag object" or "nil"))
    
    -- Test 3: Verify Cache.get_tag_by_gps() works without global guards
    game.print("[TEST] 3. Testing Cache.get_tag_by_gps()")
    local tag_from_gps = Cache.get_tag_by_gps(test_gps)
    game.print("[INFO] Cache.get_tag_by_gps() returned: " .. (tag_from_gps and "tag object" or "nil"))
    
    -- Test 4: Verify TagRegistry.get_chart_tag_by_gps() works
    game.print("[TEST] 4. Testing TagRegistry.get_chart_tag_by_gps()")
    local registry_chart_tag = TagRegistry.get_chart_tag_by_gps(test_gps)
    game.print("[INFO] TagRegistry.get_chart_tag_by_gps() returned: " .. (registry_chart_tag and "chart_tag object" or "nil"))
    
    -- Test 5: Verify no global recursion guards are set
    game.print("[TEST] 5. Verifying no global recursion guards are set")
    if rawget(_G, "__getting_chart_tag_by_gps") ~= nil then
        game.print("[FAIL] __getting_chart_tag_by_gps global flag is set!")
    else
        game.print("[PASS] __getting_chart_tag_by_gps global flag is not set")
    end
    
    if rawget(_G, "__removing_stored_tag") ~= nil then
        game.print("[FAIL] __removing_stored_tag global flag is set!")
    else
        game.print("[PASS] __removing_stored_tag global flag is not set")
    end
    
    -- Test complete tag removal
    game.print("[TEST] 6. Testing complete tag removal")
    TagRegistry.remove_tag_completely(test_gps)
    game.print("[INFO] TagRegistry.remove_tag_completely() completed")
    
    -- Check if any recursion guards are still set after tag removal
    game.print("[TEST] 7. Verifying no global recursion guards are set after tag removal")
    
    if rawget(_G, "__getting_chart_tag_by_gps") ~= nil then
        game.print("[FAIL] __getting_chart_tag_by_gps global flag is still set after removal!")
    else
        game.print("[PASS] __getting_chart_tag_by_gps global flag is not set after removal")
    end
    
    if rawget(_G, "__removing_stored_tag") ~= nil then
        game.print("[FAIL] __removing_stored_tag global flag is still set after removal!")
    else
        game.print("[PASS] __removing_stored_tag global flag is not set after removal")
    end
    
    game.print("[TEST] All tests completed")
end

return {
    run_test = run_test
}
