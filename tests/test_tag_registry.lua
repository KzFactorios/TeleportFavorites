--[[
Test file for the new TagRegistry architecture.
This test verifies that the circular dependencies between Tag, Cache, and Lookups
have been resolved through the new TagRegistry module.

USAGE:
1. Start Factorio with the mod loaded
2. Open the Lua console (Ctrl+`)
3. Run the following command: /c require("tests.test_tag_registry").run_test()
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
    
    -- Test complete tag removal
    game.print("[TEST] 6. Testing complete tag removal")
    TagRegistry.remove_tag_completely(test_gps)
    game.print("[INFO] TagRegistry.remove_tag_completely() completed")
    
    game.print("[TEST] All tests completed")
end
    
    -- Test 5: Check recursion guards are cleared properly
    game.print("[TEST] 5. Checking recursion guards are cleared properly")
    
    -- First check the initial state
    local initial_guard_state = {
        getting_chart_tag_by_gps = rawget(_G, "__getting_chart_tag_by_gps") ~= nil,
        removing_stored_tag = rawget(_G, "__removing_stored_tag") ~= nil
    }
    
    game.print("[INFO] Initial guard states: " .. 
        "getting_chart_tag_by_gps=" .. tostring(initial_guard_state.getting_chart_tag_by_gps) .. ", " ..
        "removing_stored_tag=" .. tostring(initial_guard_state.removing_stored_tag))
    
    -- Now trigger an operation that uses guards and check they're cleared
    TagRegistry.get_chart_tag_by_gps(test_gps)
    Cache.remove_stored_tag(test_gps)
    
    local final_guard_state = {
        getting_chart_tag_by_gps = rawget(_G, "__getting_chart_tag_by_gps") ~= nil,
        removing_stored_tag = rawget(_G, "__removing_stored_tag") ~= nil
    }
    
    game.print("[INFO] Final guard states: " .. 
        "getting_chart_tag_by_gps=" .. tostring(final_guard_state.getting_chart_tag_by_gps) .. ", " ..
        "removing_stored_tag=" .. tostring(final_guard_state.removing_stored_tag))
    
    if not final_guard_state.getting_chart_tag_by_gps and not final_guard_state.removing_stored_tag then
        game.print("[PASS] All recursion guards are properly cleared after operations")
    else
        game.print("[FAIL] Some recursion guards were not cleared: " .. 
            "getting_chart_tag_by_gps=" .. tostring(final_guard_state.getting_chart_tag_by_gps) .. ", " ..
            "removing_stored_tag=" .. tostring(final_guard_state.removing_stored_tag))
    end
    
    -- Test 5: Check recursion guards are cleared properly
    game.print("[TEST] 5. Checking recursion guards are cleared properly")
    
    -- First check the initial state
    local initial_guard_state = {
        getting_chart_tag_by_gps = rawget(_G, "__getting_chart_tag_by_gps") ~= nil,
        removing_stored_tag = rawget(_G, "__removing_stored_tag") ~= nil
    }
    
    game.print("[INFO] Initial guard states: " .. 
        "getting_chart_tag_by_gps=" .. tostring(initial_guard_state.getting_chart_tag_by_gps) .. ", " ..
        "removing_stored_tag=" .. tostring(initial_guard_state.removing_stored_tag))
    
    -- Now trigger an operation that uses guards and check they're cleared
    TagRegistry.get_chart_tag_by_gps(test_gps)
    Cache.remove_stored_tag(test_gps)
    
    local final_guard_state = {
        getting_chart_tag_by_gps = rawget(_G, "__getting_chart_tag_by_gps") ~= nil,
        removing_stored_tag = rawget(_G, "__removing_stored_tag") ~= nil
    }
    
    game.print("[INFO] Final guard states: " .. 
        "getting_chart_tag_by_gps=" .. tostring(final_guard_state.getting_chart_tag_by_gps) .. ", " ..
        "removing_stored_tag=" .. tostring(final_guard_state.removing_stored_tag))
    
    if not final_guard_state.getting_chart_tag_by_gps and not final_guard_state.removing_stored_tag then
        game.print("[PASS] All recursion guards are properly cleared after operations")
    else
        game.print("[FAIL] Some recursion guards were not cleared: " .. 
            "getting_chart_tag_by_gps=" .. tostring(final_guard_state.getting_chart_tag_by_gps) .. ", " ..
            "removing_stored_tag=" .. tostring(final_guard_state.removing_stored_tag))
    end
      -- Test 5: Verify no global recursion guards are set
    game.print("[TEST] 5. Verifying no global recursion guards are set")
    if rawget(_G, "__getting_chart_tag") ~= nil then
        game.print("[FAIL] __getting_chart_tag global flag is set!")
    else
        game.print("[PASS] __getting_chart_tag global flag is not set")
    end
    
    -- Test 6: Test the complete tag removal process
    game.print("[TEST] 6. Testing complete tag removal")
    
    -- First create a chart tag in the game world
    local player_force = game.player.force
    local player_surface = game.player.surface
    local test_chart_position = {x = 10, y = 10}
    local test_chart_gps = GPSUtils.gps_from_map_position(test_chart_position, surface_index)
    
    local created_chart_tag = player_force.add_chart_tag(player_surface, {
        position = test_chart_position,
        text = "Test Tag",
        icon = {type = "virtual", name = "signal-info"}
    })
    
    if created_chart_tag and created_chart_tag.valid then
        game.print("[INFO] Created test chart tag successfully")
        
        -- Create and store the tag in cache
        local created_tag = Tag.new(test_chart_gps, {game.player.index})
        local tag_cache = Cache.get_surface_tags(surface_index)
        tag_cache[test_chart_gps] = created_tag
        game.print("[INFO] Stored tag in cache successfully")
        
        -- Now try to remove it completely
        TagRegistry.remove_tag_completely(test_chart_gps)
        game.print("[INFO] Called remove_tag_completely")
        
        -- Verify chart tag is removed
        local chart_tag_after_removal = TagRegistry.get_chart_tag_by_gps(test_chart_gps)
    if chart_tag_after_removal and chart_tag_after_removal.valid then
            game.print("[FAIL] Chart tag was not removed!")
            chart_tag_after_removal.destroy() -- Clean up
        else 
            game.print("[PASS] Chart tag was removed successfully")
        end
        
        -- Verify tag is removed from cache
        local tag_after_removal = Cache.get_tag_by_gps(test_chart_gps)
        if tag_after_removal then
            game.print("[FAIL] Tag was not removed from cache!")
        else
            game.print("[PASS] Tag was removed from cache successfully")
        end
    else
        game.print("[ERROR] Could not create test chart tag")
    end")
    end
    
    if rawget(_G, "__getting_tag_by_gps") ~= nil then
        game.print("[FAIL] __getting_tag_by_gps global flag is set!")
    else
        game.print("[PASS] __getting_tag_by_gps global flag is not set")
    end
    
    if rawget(_G, "__removing_stored_tag") ~= nil then
        game.print("[FAIL] __removing_stored_tag global flag is set!")
    else
        game.print("[PASS] __removing_stored_tag global flag is not set")
    end
    
    if rawget(_G, "__removing_chart_tag_from_cache") ~= nil then
        game.print("[FAIL] __removing_chart_tag_from_cache global flag is set!")
    else
        game.print("[PASS] __removing_chart_tag_from_cache global flag is not set")
    end
    
    -- Final test: Create a full tag removal cycle
    game.print("[TEST] 6. Testing full tag removal cycle")
    Cache.remove_stored_tag(test_gps)
    game.print("[INFO] Cache.remove_stored_tag() completed")
    
    -- Verify global flag state after removal
    game.print("[TEST] 7. Verifying no global recursion guards are set after removal")
    if rawget(_G, "__getting_chart_tag") ~= nil then
        game.print("[FAIL] __getting_chart_tag global flag is set after removal!")
    else
        game.print("[PASS] __getting_chart_tag global flag is not set after removal")
    end
    
    if rawget(_G, "__getting_tag_by_gps") ~= nil then
        game.print("[FAIL] __getting_tag_by_gps global flag is set after removal!")
    else
        game.print("[PASS] __getting_tag_by_gps global flag is not set after removal")
    end
    
    if rawget(_G, "__removing_stored_tag") ~= nil then
        game.print("[FAIL] __removing_stored_tag global flag is set after removal!")
    else
        game.print("[PASS] __removing_stored_tag global flag is not set after removal")
    end
    
    if rawget(_G, "__removing_chart_tag_from_cache") ~= nil then
        game.print("[FAIL] __removing_chart_tag_from_cache global flag is set after removal!")
    else
        game.print("[PASS] __removing_chart_tag_from_cache global flag is not set after removal")
    end
    
    game.print("[TEST] All tests completed")
end

-- Run the test
run_test()

-- Return true to indicate successful execution
return true
