-- Test: Icon preservation from tag editor to favorites bar
-- This test verifies that when a favorite is created from the tag editor,
-- the icon from chart_tag.icon is properly preserved and displayed in the favorites bar
-- 
-- The flow is:
-- 1. Tag has chart_tag.icon (runtime userdata)
-- 2. During sanitization, chart_tag is removed for storage
-- 3. During rehydration (via FavoriteRehydration), chart_tag is restored from cache
-- 4. Favorites bar displays the icon from the rehydrated chart_tag.icon

local test_name = "test_tag_editor_icon_preservation"

local function run_test()
  game.print("=== " .. test_name .. " ===")
  
  local player = game.get_player(1)
  if not player then
    game.print("❌ No player found")
    return
  end

  game.print("📝 Test Instructions:")
  game.print("1. Place a map tag somewhere on the map with a custom icon")
  game.print("2. Right-click on the tag to open the tag editor")
  game.print("3. Click the favorite button (star) to enable it")
  game.print("4. Click confirm to save")
  game.print("5. Check if the favorites bar shows the same icon")
  game.print("6. Look for debug messages in the log about icon preservation")
  game.print("")
  game.print("Expected: The favorites bar slot should show the same icon as the chart tag")
  game.print("📋 Check the debug logs for:")
  game.print("  - [PLAYER_FAVORITES] Tag sanitized for favorite storage")  
  game.print("  - [CACHE] get_tag_by_gps - found tag in cache")
  game.print("  - [LOOKUPS] get_chart_tag_by_gps")
  game.print("  - [FAVE_BAR] Rehydrate step 1 - got tag from cache")
  game.print("  - [FAVE_BAR] Rehydrate step 2 - lookup chart_tag")
  game.print("  - [FAVE_BAR] Rehydrate step 3 - attached chart_tag to tag")
  game.print("  - [FAVE_BAR] Icon resolution for slot")
end

-- Register the test command
commands.add_command(test_name, "Test icon preservation from tag editor to favorites bar", run_test)

game.print("✅ Test registered: /" .. test_name)
