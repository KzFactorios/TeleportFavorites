---@diagnostic disable
local Tag = require("core.tag.tag")
local Helpers = require("tests.mocks.mock_helpers")
local make_player = require("tests.mocks.mock_player")
local make_surface = require("tests.mocks.mock_surface")
local Constants = require("constants")
local BLANK_GPS = "1000000.1000000.1"

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
  local player = make_player(2)
  assert(tag:is_player_favorite(player), "Should be favorite")
  player.index = 1
  assert(not tag:is_player_favorite(player), "Should not be favorite")
end

local function test_tag_is_owner()
  local tag = Tag.new("1.2.1")
  tag.chart_tag = { last_user = "TestPlayer" }
  local player = make_player(1, "TestPlayer")
  assert(tag:is_owner(player), "Should be owner")
  player.name = "OtherPlayer"
  assert(not tag:is_owner(player), "Should not be owner")
end

local function test_teleport_player_with_messaging_success()
  local tag = Tag.new("1.2.1")
  local player = make_player(1)
  player.driving = false
  player.vehicle = nil
  local pos = {x=0, y=0}
  local surface = make_surface(1)
  local result = Tag.teleport_player_with_messaging(player, pos, surface)
  print("[TEST] Tag.teleport_player_with_messaging result:", result, "Expected:", Constants.enums.return_state.SUCCESS)
  assert(result == Constants.enums.return_state.SUCCESS, "Teleport should succeed")
end

local function test_teleport_player_with_messaging_failures()
  local tag = Tag.new("1.2.1")
  local player = make_player(1)
  local pos = {x=0, y=0}
  -- No surface
  local result = Tag.teleport_player_with_messaging(player, pos, nil)
  assert(type(result) == "string" and result:find("Surface is missing"), "Should fail if surface is missing")
  -- No player
  result = Tag.teleport_player_with_messaging(nil, pos, make_surface(1))
  assert(type(result) == "string" and result:find("Player is missing"), "Should fail if player is missing")
end

local function test_create_for_favorite()
  it("should create tag for valid favorite", function()
    local favorite = {gps = "1.2.3", text = "Test Tag", locked = false}
    local tag = Tag.create_for_favorite(favorite)
    assert.is_not_nil(tag, "Tag should be created")
    assert.equals(tag.gps, "1.2.3", "Tag GPS should match favorite GPS")
    assert.equals(tag.text, "Test Tag", "Tag text should match favorite text")
    assert.is_false(tag.locked, "Tag should not be locked")
  end)

  it("should not create tag for blank favorite", function()
        local blank = {gps = BLANK_GPS, text = "", locked = false}
        assert.is_false(Tag.create_for_favorite(blank))
    end)
end

describe("Tag", function()
  it("should create a tag and check fields", test_tag_creation)
  it("should add and remove faved_by_player", test_tag_add_remove_faved_by_player)
  it("should check is_player_favorite", test_tag_is_player_favorite)
  it("should check is_owner", test_tag_is_owner)
  it("should teleport player with messaging (success)", test_teleport_player_with_messaging_success)
  it("should handle teleport player with messaging failures", test_teleport_player_with_messaging_failures)
end)
