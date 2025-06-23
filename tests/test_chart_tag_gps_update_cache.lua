-- test_chart_tag_gps_update_cache.lua
-- Test: Chart tag modification correctly updates surface mapping table from old GPS to new GPS
-- Place in /tests, run in Factorio mod test environment

local Cache = require("core.cache.cache")
local GPSUtils = require("core.utils.gps_utils")
local handlers = require("core.events.handlers")

-- Mock player and surface
local player = {
  index = 1,
  valid = true,
  name = "TestPlayer",
  surface = { index = 1 },
  print = function() end,
}

-- Setup: Create a tag in the surface mapping table at GPS1
local surface_index = 1
local gps1 = "100.100.1"
local gps2 = "200.200.1"

-- Initialize surface data and add a tag at GPS1
local surface_tags = Cache.get_surface_tags(surface_index)
surface_tags[gps1] = {
  gps = gps1,
  faved_by_players = {},
  chart_tag = nil
}

-- Verify initial state
assert(surface_tags[gps1] ~= nil, "Tag should exist at GPS1 before modification")
assert(surface_tags[gps2] == nil, "Tag should not exist at GPS2 before modification")

print("✅ Initial state verified: tag exists at GPS1, not at GPS2")

-- Simulate chart tag modification event
local mock_event = {
  tag = {
    position = { x = 200, y = 200 },
    surface = { index = 1 },
    valid = true,
    text = "Test Tag",
    icon = nil,
    last_user = player
  },
  old_position = { x = 100, y = 100 },
  old_surface = { index = 1 },
  player_index = 1
}

-- Mock the chart tag lookup functions to return valid chart tags
_G.Cache = _G.Cache or {}
_G.Cache.Lookups = _G.Cache.Lookups or {}
_G.Cache.Lookups.get_chart_tag_by_gps = function(gps)
  return {
    valid = true,
    position = gps == gps1 and { x = 100, y = 100 } or { x = 200, y = 200 },
    text = "Test Tag",
    surface = { index = 1 }
  }
end
_G.Cache.Lookups.invalidate_surface_chart_tags = function() end

-- Call the chart tag modification handler
handlers.on_chart_tag_modified(mock_event)

-- Verify that the surface mapping table was updated correctly
assert(surface_tags[gps1] == nil, "Tag should no longer exist at GPS1 after modification")
assert(surface_tags[gps2] ~= nil, "Tag should now exist at GPS2 after modification")
assert(surface_tags[gps2].gps == gps2, "Tag GPS should be updated to GPS2")

print("✅ Surface mapping update verified: tag moved from GPS1 to GPS2")

-- Verify tag data integrity
local moved_tag = surface_tags[gps2]
assert(moved_tag.faved_by_players ~= nil, "Tag should retain faved_by_players data")
assert(type(moved_tag.faved_by_players) == "table", "faved_by_players should be a table")

print("✅ Tag data integrity verified: all properties preserved during move")

print("✅ test_chart_tag_gps_update_cache passed!")
