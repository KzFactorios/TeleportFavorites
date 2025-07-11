-- Debug spy creation in handlers_chart_tag_added test

package.path = './?.lua;' .. package.path

require('tests.mocks.factorio_test_env')

-- Set up exactly like the test does
local PlayerFavoritesMocks = require("tests.mocks.player_favorites_mocks")

-- Create mocks for dependencies like the test does
local Cache = {
  init = function() end,
  get_player_data = function() return {} end,
  set_tag_editor_data = function() end,
  create_tag_editor_data = function() return {} end,
  get_tag_by_gps = function() return nil end,
  Lookups = {
    invalidate_surface_chart_tags = function() end,
    get_chart_tag_cache = function() return {} end,
  }
}

local PositionUtils = {
  needs_normalization = function(position) 
    if not position then return false end
    return position.x ~= math.floor(position.x) or position.y ~= math.floor(position.y)
  end,
  normalize_if_needed = function(pos) 
    if not pos then return pos end
    return {x = math.floor(pos.x), y = math.floor(pos.y)}
  end,
}

local TagEditorEventHelpers = {
  normalize_and_replace_chart_tag = function(chart_tag, player)
    local normalized_pos = {
      x = math.floor(chart_tag.position.x),
      y = math.floor(chart_tag.position.y)
    }
    
    local new_chart_tag = {
      position = normalized_pos,
      valid = true,
      surface = chart_tag.surface,
      text = chart_tag.text,
      last_user = player
    }
    
    return new_chart_tag, {
      old = chart_tag.position,
      new = normalized_pos
    }
  end,
}

local ErrorHandler = {
  debug_log = function() end
}

-- Mock package.loaded for dependencies
package.loaded["core.cache.cache"] = Cache
package.loaded["core.utils.position_utils"] = PositionUtils
package.loaded["core.events.tag_editor_event_helpers"] = TagEditorEventHelpers
package.loaded["core.utils.error_handler"] = ErrorHandler

print("=== Debugging Spy Creation ===")

-- Check what's in package.loaded
print("PositionUtils in package.loaded:", package.loaded["core.utils.position_utils"] ~= nil)
print("Has needs_normalization:", package.loaded["core.utils.position_utils"].needs_normalization ~= nil)
print("needs_normalization type:", type(package.loaded["core.utils.position_utils"].needs_normalization))

print("ErrorHandler in package.loaded:", package.loaded["core.utils.error_handler"] ~= nil) 
print("Has debug_log:", package.loaded["core.utils.error_handler"].debug_log ~= nil)
print("debug_log type:", type(package.loaded["core.utils.error_handler"].debug_log))

print("Cache.Lookups exists:", package.loaded["core.cache.cache"].Lookups ~= nil)
print("invalidate_surface_chart_tags exists:", package.loaded["core.cache.cache"].Lookups.invalidate_surface_chart_tags ~= nil)
print("invalidate_surface_chart_tags type:", type(package.loaded["core.cache.cache"].Lookups.invalidate_surface_chart_tags))

-- Now try to create spies
local spy_utils = require("tests.mocks.spy_utils")
local make_spy = spy_utils.make_spy

print("\nCreating spies...")

print("Creating spy for needs_normalization...")
local success1, spy1 = pcall(make_spy, package.loaded["core.utils.position_utils"], "needs_normalization")
if success1 then
    print("  Success! Spy object type:", type(spy1))
    print("  Spy object has was_called:", spy1.was_called ~= nil)
else
    print("  ERROR:", spy1)
end

print("Creating spy for debug_log...")
local success2, spy2 = pcall(make_spy, package.loaded["core.utils.error_handler"], "debug_log")
if success2 then
    print("  Success! Spy object type:", type(spy2))
    print("  Spy object has was_called:", spy2.was_called ~= nil)
else
    print("  ERROR:", spy2)
end

print("Creating spy for invalidate_surface_chart_tags...")
local success3, spy3 = pcall(make_spy, package.loaded["core.cache.cache"].Lookups, "invalidate_surface_chart_tags")
if success3 then
    print("  Success! Spy object type:", type(spy3))
    print("  Spy object has was_called:", spy3.was_called ~= nil)
else
    print("  ERROR:", spy3)
end

-- Check if the spies are stored correctly
print("\nChecking spy storage...")
print("needs_normalization_spy exists:", package.loaded["core.utils.position_utils"].needs_normalization_spy ~= nil)
print("debug_log_spy exists:", package.loaded["core.utils.error_handler"].debug_log_spy ~= nil)
print("invalidate_surface_chart_tags_spy exists:", package.loaded["core.cache.cache"].Lookups.invalidate_surface_chart_tags_spy ~= nil)

if package.loaded["core.utils.position_utils"].needs_normalization_spy then
    local spy_obj = package.loaded["core.utils.position_utils"].needs_normalization_spy
    print("needs_normalization_spy type:", type(spy_obj))
    print("needs_normalization_spy.was_called type:", type(spy_obj.was_called))
    
    -- Test calling was_called
    print("Testing was_called()...")
    local success_call, result = pcall(spy_obj.was_called, spy_obj)
    if success_call then
        print("  was_called() returned:", result)
    else
        print("  ERROR in was_called():", result)
    end
end

print("=== End Debug ===")
