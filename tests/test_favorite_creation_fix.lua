-- test_favorite_creation_fix.lua
-- Test to verify that favorites are actually created and not just observer notifications

local PlayerFavorites = require("core.favorite.player_favorites")
local Cache = require("core.cache.cache")

-- Mock globals and player for testing
local test_results = {}

-- Mock storage
storage = {
  players = {}
}

-- Mock game and player
game = {
  tick = 0,
  players = {}
}

local mock_player = {
  valid = true,
  index = 1,
  name = "test_player",
  surface = {
    index = 1,
    name = "nauvis"
  }
}

game.players[1] = mock_player

function test_favorite_creation()
  -- Initialize player data
  Cache.init_player_data(mock_player)
  
  -- Create PlayerFavorites instance and add a favorite
  local player_favorites = PlayerFavorites.new(mock_player)
  local test_gps = "100.200.1"
  
  -- Test adding favorite
  local favorite, error_msg = player_favorites:add_favorite(test_gps)
  
  if favorite then
    table.insert(test_results, "✅ add_favorite() returned favorite object")
    
    -- Check if it was actually stored
    local stored_favorites = Cache.get_player_favorites(mock_player)
    local found = false
    for i, fav in ipairs(stored_favorites) do
      if fav.gps == test_gps then
        found = true
        break
      end
    end
    
    if found then
      table.insert(test_results, "✅ Favorite was actually stored in cache/storage")
    else
      table.insert(test_results, "❌ Favorite was NOT stored in cache/storage")
    end
  else
    table.insert(test_results, "❌ add_favorite() failed: " .. (error_msg or "Unknown error"))
  end
  
  -- Test removing favorite
  local success, remove_error = player_favorites:remove_favorite(test_gps)
  
  if success then
    table.insert(test_results, "✅ remove_favorite() succeeded")
    
    -- Check if it was actually removed
    local stored_favorites = Cache.get_player_favorites(mock_player)
    local found = false
    for i, fav in ipairs(stored_favorites) do
      if fav.gps == test_gps then
        found = true
        break
      end
    end
    
    if not found then
      table.insert(test_results, "✅ Favorite was actually removed from cache/storage")
    else
      table.insert(test_results, "❌ Favorite was NOT removed from cache/storage")
    end
  else
    table.insert(test_results, "❌ remove_favorite() failed: " .. (remove_error or "Unknown error"))
  end
end

function run_tests()
  test_results = {}
  
  local success, error_msg = pcall(test_favorite_creation)
  
  if not success then
    table.insert(test_results, "❌ Test crashed: " .. (error_msg or "Unknown error"))
  end
  
  print("=== Favorite Creation Fix Test Results ===")
  for _, result in ipairs(test_results) do
    print(result)
  end
  print("=== End Test Results ===")
end

return {
  run_tests = run_tests
}
