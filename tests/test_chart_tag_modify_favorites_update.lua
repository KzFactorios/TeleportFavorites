---@diagnostic disable: undefined-global

--[[
Test for Chart Tag Modification - Player Favorites Update
=========================================================

This test verifies that when a chart tag is modified (moved), all player favorites
that reference the old GPS are properly updated to the new GPS, including the 
acting player's favorites.

Manual Test Instructions:
1. Create a chart tag at position (100, 100)
2. Add it to favorites for multiple players including yourself
3. Move the chart tag to a new position (e.g., 200, 200)
4. Check that ALL players' favorites (including your own) now show the new GPS

Expected Results:
- Acting player's favorites should be updated to new GPS
- Other players' favorites should be updated to new GPS  
- Storage should reflect the new GPS coordinates
- No favorites should be "orphaned" with the old GPS
--]]

local Cache = require("core.cache.cache")
local PlayerFavorites = require("core.favorite.player_favorites")
local GPSUtils = require("core.utils.gps_utils")

local function test_chart_tag_modify_favorites_update()
  print("Testing chart tag modification and favorites update...")
  
  -- This test requires in-game execution with multiple players
  if not game or not game.players then
    print("⚠️ This test requires in-game execution")
    return
  end
  
  local test_players = {}
  local player_count = 0
  for _, player in pairs(game.players) do
    if player and player.valid then
      table.insert(test_players, player)
      player_count = player_count + 1
      if player_count >= 2 then break end -- Only need 2 players for test
    end
  end
  
  if #test_players < 1 then
    print("⚠️ At least 1 player required for this test")
    return
  end
  
  print("✅ Found " .. #test_players .. " test players")
  
  -- Test GPS coordinates
  local old_gps = "100.100.1"
  local new_gps = "200.200.1"
  
  -- Add the old GPS to each player's favorites
  for i, player in ipairs(test_players) do
    local pf = PlayerFavorites.new(player)
    local success, error_msg = pf:add_favorite(old_gps)
    if success then
      print("✅ Added favorite for player " .. player.name .. " with GPS: " .. old_gps)
    else
      print("❌ Failed to add favorite for player " .. player.name .. ": " .. (error_msg or "unknown error"))
    end
  end
  
  -- Simulate the chart tag modification by calling update_gps_for_all_players
  print("Simulating chart tag modification from " .. old_gps .. " to " .. new_gps .. "...")
  local affected_players = PlayerFavorites.update_gps_for_all_players(old_gps, new_gps, nil) -- Include all players
  
  print("✅ GPS update completed. Affected players: " .. #affected_players)
    -- Verify that all players' favorites were updated
  local all_updated = true
  for i, player in ipairs(test_players) do
    local pf = PlayerFavorites.new(player)
    
    -- Check if old GPS still exists (should not)
    local old_fav, old_slot = pf:get_favorite_by_gps(old_gps)
    if old_fav then
      print("❌ Player " .. player.name .. " still has old GPS " .. old_gps .. " in slot " .. old_slot)
      all_updated = false
    end
    
    -- Check if new GPS exists (should exist)
    local new_fav, new_slot = pf:get_favorite_by_gps(new_gps)
    if new_fav then
      print("✅ Player " .. player.name .. " has new GPS " .. new_gps .. " in slot " .. new_slot)
      
      -- CRITICAL: Check that favorite.tag.gps is also updated
      if new_fav.tag and new_fav.tag.gps then
        if new_fav.tag.gps == new_gps then
          print("✅ Player " .. player.name .. " favorite.tag.gps correctly updated to " .. new_gps)
        else
          print("❌ Player " .. player.name .. " favorite.tag.gps is " .. new_fav.tag.gps .. " but should be " .. new_gps)
          all_updated = false
        end
      else
        print("⚠️ Player " .. player.name .. " favorite.tag is nil or has no gps field")
      end
    else
      print("❌ Player " .. player.name .. " does not have new GPS " .. new_gps)
      all_updated = false
    end
  end
    if all_updated then
    print("✅ All player favorites updated successfully!")
    print("✅ Favorites bar should be automatically rebuilt via cache_updated observer")
  else
    print("❌ Some player favorites were not updated correctly")
  end
  
  -- Clean up - remove the test favorites
  for i, player in ipairs(test_players) do
    local pf = PlayerFavorites.new(player)
    pf:remove_favorite(new_gps)
  end
  
  print("Test completed!")
end

-- Export for manual testing
return {
  test_chart_tag_modify_favorites_update = test_chart_tag_modify_favorites_update
}
