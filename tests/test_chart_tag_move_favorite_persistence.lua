-- test_chart_tag_move_favorite_persistence.lua
-- Test: Moving a chart tag updates favorite GPS and preserves is_favorite state
-- Place in /tests, run in Factorio mod test environment

local Cache = require("core.cache.cache")
local PlayerFavorites = require("core.favorite.player_favorites")
local Tag = require("core.tag.tag")
local GPSUtils = require("core.utils.gps_utils")

-- Mock player and surface
local player = {
  index = 1,
  valid = true,
  name = "TestPlayer",
  surface = { index = 1 },
  print = function() end,
}

-- Setup: Add a favorite at GPS1
local gps1 = "100.100.1"
local gps2 = "200.200.1"
local pf = PlayerFavorites.new(player)
local fav, err = pf:add_favorite(gps1)
assert(fav, "Favorite should be added: " .. tostring(err))
assert(fav.gps == gps1, "Favorite GPS should match initial GPS")

-- Simulate moving the chart tag from gps1 to gps2
local updated = pf:update_gps_coordinates(gps1, gps2)
assert(updated, "Favorite GPS should be updated after tag move")

-- Check that the favorite slot now points to gps2 and is not blank
local found = false
for i, f in ipairs(pf.favorites) do
  if f.gps == gps2 then
    found = true
    assert(not require("core.favorite.favorite").is_blank_favorite(f), "Favorite slot should not be blank after move")
  end
end
assert(found, "Favorite with new GPS should exist after move")

print("✅ test_chart_tag_move_favorite_persistence passed!")
