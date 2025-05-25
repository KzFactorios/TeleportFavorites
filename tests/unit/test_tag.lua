-- tests/unit/test_tag.lua
-- Unit tests for core.tag.tag
local Tag = require("core.tag.tag")
local GPS = require("core.gps.gps")
local Constants = require("constants")

local function mock_player(index, name, surface_index)
  return {
    index = index or 1,
    name = name or "TestPlayer",
    surface = { index = surface_index or 1 },
    valid = true,
    teleport = function() return true end,
    print = function(self, message) return message end,
    character = true,
    driving = false,
    vehicle = nil,
    riding_state = nil,
  }
end

local function mock_surface(index)
  return {
    index = index or 1,
    find_non_colliding_position = function() return {x=0, y=0} end,
    can_place_entity = function() return true end,
  }
end

local function test_tag_creation()
  local tag = Tag.new("1.2.1", {1,2})
  assert(tag.gps == "1.2.1", "Tag GPS should be set")
  assert(#tag.faved_by_players == 2, "Tag faved_by_players should be set")
end

local function test_tag_add_remove_faved_by_player()
  local tag = Tag.new("1.2.1")
  tag:add_faved_by_player(1)
  assert(tag.faved_by_players[1] == 1, "Player index should be added")
  tag:add_faved_by_player(1)
  assert(#tag.faved_by_players == 1, "Duplicate player index should not be added")
  tag:remove_faved_by_player(1)
  assert(#tag.faved_by_players == 0, "Player index should be removed")
end

local function test_tag_is_player_favorite()
  local tag = Tag.new("1.2.1", {2,3})
  local player = mock_player(2)
  assert(tag:is_player_favorite(player), "Should be favorite")
  player.index = 1
  assert(not tag:is_player_favorite(player), "Should not be favorite")
end

local function test_tag_is_owner()
  local tag = Tag.new("1.2.1")
  tag.chart_tag = { last_user = "TestPlayer" }
  local player = mock_player(1, "TestPlayer")
  assert(tag:is_owner(player), "Should be owner")
  player.name = "OtherPlayer"
  assert(not tag:is_owner(player), "Should not be owner")
end

local function test_teleport_player_with_messaging_success()
  local tag = Tag.new("1.2.1")
  local player = mock_player(1)
  local pos = {x=0, y=0}
  local surface = mock_surface(1)
  local result = Tag.teleport_player_with_messaging(player, pos, surface)
  assert(result == Constants.enums.return_state.SUCCESS, "Teleport should succeed")
end

local function test_teleport_player_with_messaging_failures()
  local tag = Tag.new("1.2.1")
  local player = mock_player(1)
  local pos = {x=0, y=0}
  -- No surface
  local result = Tag.teleport_player_with_messaging(player, pos, nil)
  assert(type(result) == "string" and result:find("Surface is missing"), "Should fail if surface is missing")
  -- No player
  result = Tag.teleport_player_with_messaging(nil, pos, mock_surface(1))
  assert(type(result) == "string" and result:find("Player is missing"), "Should fail if player is missing")
end

local function run_all()
  test_tag_creation()
  test_tag_add_remove_faved_by_player()
  test_tag_is_player_favorite()
  test_tag_is_owner()
  test_teleport_player_with_messaging_success()
  test_teleport_player_with_messaging_failures()
  print("All Tag tests passed.")
end

run_all()
