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

describe("Tag edge cases", function()
  local Tag = require("core.tag.tag")
  local make_player = require("tests.mocks.mock_player")

  it("should handle Tag.new with nil/empty gps and faved_by_players", function()
    local tag = Tag.new(nil)
    assert.is_table(tag)
    assert.is_nil(tag.gps)
    tag = Tag.new("")
    assert.is_table(tag)
    assert.equals("", tag.gps)
    tag = Tag.new("1.2.3", nil)
    assert.is_table(tag)
    assert.same({}, tag.faved_by_players)
  end)

  it("should handle is_player_favorite and is_owner with nil/invalid input", function()
    local tag = Tag.new("1.2.3", { 1 })
    assert.is_false(tag:is_player_favorite(nil))
    assert.is_false(tag:is_owner(nil))
  end)

  it("should not add duplicate player indices", function()
    local tag = Tag.new("1.2.3")
    tag:add_faved_by_player(1)
    tag:add_faved_by_player(1)
    assert.equals(1, #tag.faved_by_players)
  end)
end)

describe("Tag additional edge cases and error handling", function()
  local Tag = require("core.tag.tag")
  local make_player = require("tests.mocks.mock_player")
  local make_surface = require("tests.mocks.mock_surface")
  local Constants = require("constants")
  local BLANK_GPS = "1000000.1000000.1"

  it("get_chart_tag returns nil if Lookups returns nil", function()
    local tag = Tag.new("1.2.1")
    tag.chart_tag = nil
    local old_lookups = package.loaded["core.cache.lookups"]
    package.loaded["core.cache.lookups"] = { get_chart_tag_by_gps = function() return nil end }
    assert.is_nil(tag:get_chart_tag())
    package.loaded["core.cache.lookups"] = old_lookups
  end)

  it("rehome_chart_tag returns error for nil/incomplete tag", function()
    local tag = Tag.new(nil)
    local player = make_player(1)
    local err = tag:rehome_chart_tag(nil, "[gps=1,1,1]")
    assert.is_string(err)
    err = tag:rehome_chart_tag(player, nil)
    assert.is_string(err)
  end)

  it("unlink_and_destroy handles nil and incomplete tags", function()
    assert.has_no.errors(function() Tag.unlink_and_destroy(nil) end)
    assert.has_no.errors(function() Tag.unlink_and_destroy({}) end)
    assert.has_no.errors(function() Tag.unlink_and_destroy({ gps = nil }) end)
  end)

  it("is_owner returns false if chart_tag is missing or last_user mismatches", function()
    local tag = Tag.new("1.2.1")
    tag.chart_tag = nil
    local player = make_player(1, "TestPlayer")
    assert.is_false(tag:is_owner(player))
    tag.chart_tag = { last_user = "OtherPlayer" }
    assert.is_false(tag:is_owner(player))
  end)

  it("multiplayer: multiple players can favorite/unfavorite the same tag", function()
    local tag = Tag.new("1.2.1")
    tag:add_faved_by_player(1)
    tag:add_faved_by_player(2)
    assert.same({1,2}, tag.faved_by_players)
    tag:remove_faved_by_player(1)
    assert.same({2}, tag.faved_by_players)
    tag:remove_faved_by_player(2)
    assert.same({}, tag.faved_by_players)
  end)
end)

describe("Tag missed error/edge branches (Factorio runtime)", function()
  local Tag = require("core.tag.tag")
  local make_player = require("tests.mocks.mock_player")
  local BLANK_GPS = "1000000.1000000.1"

  it("rehome_chart_tag returns error if game or player.force is missing", function()
    local tag = Tag.new("1.2.1")
    local player = make_player(1)
    -- Simulate missing game global
    _G.game = nil
    local err = tag:rehome_chart_tag(player, "[gps=1,1,1]")
    assert.is_string(err)
    -- Simulate missing player.force
    _G.game = { players = { player } }
    player.force = nil
    err = tag:rehome_chart_tag(player, "[gps=1,1,1]")
    assert.is_string(err)
  end)

  it("rehome_chart_tag returns error if add_chart_tag fails", function()
    local tag = Tag.new("1.2.1")
    local player = make_player(1)
    player.force = { add_chart_tag = function() return nil end }
    _G.game = { players = { player } }
    local err = tag:rehome_chart_tag(player, "[gps=1,1,1]")
    assert.is_string(err)
  end)

  it("unlink_and_destroy does not error if chart_tag is already destroyed", function()
    local tag = Tag.new("1.2.1")
    tag.chart_tag = { valid = false, destroy = function() end }
    assert.has_no.errors(function() Tag.unlink_and_destroy(tag) end)
  end)
end)

describe("Tag 100% coverage edge cases", function()
  local Tag = require("core.tag.tag")
  local make_player = require("tests.mocks.mock_player")
  local make_surface = require("tests.mocks.mock_surface")
  local Constants = require("constants")
  local BLANK_GPS = "1000000.1000000.1"

  it("get_chart_tag returns nil if Lookups returns nil", function()
    local tag = Tag.new("1.2.1")
    tag.chart_tag = nil
    local old_lookups = package.loaded["core.cache.lookups"]
    package.loaded["core.cache.lookups"] = { get_chart_tag_by_gps = function() return nil end }
    assert.is_nil(tag:get_chart_tag())
    package.loaded["core.cache.lookups"] = old_lookups
  end)

  it("rehome_chart_tag returns error for all error branches", function()
    local tag = Tag.new(nil)
    local player = make_player(1)
    -- Invalid self
    assert.is_string(tag:rehome_chart_tag(player, "[gps=1,1,1]"))
    -- Invalid destination
    tag = Tag.new("1.2.1")
    assert.is_string(tag:rehome_chart_tag(player, nil))
    -- GPS parse fail
    local old_map_position_from_gps = require("core.gps.gps").map_position_from_gps
    require("core.gps.gps").map_position_from_gps = function() return nil end
    assert.is_string(tag:rehome_chart_tag(player, "bad_gps"))
    require("core.gps.gps").map_position_from_gps = old_map_position_from_gps
    -- Aligned position fail
    local old_normalize = require("core.gps.gps").normalize_landing_position
    require("core.gps.gps").normalize_landing_position = function() return nil end
    assert.is_string(tag:rehome_chart_tag(player, "[gps=1,1,1]"))
    require("core.gps.gps").normalize_landing_position = old_normalize
    -- Chart tag creation fail
    player.force = { add_chart_tag = function() return nil end }
    _G.game = { players = { player } }
    assert.is_string(tag:rehome_chart_tag(player, "[gps=1,1,1]"))
  end)

  it("unlink_and_destroy covers all branches", function()
    local tag = Tag.new("1.2.1")
    tag.chart_tag = { valid = false, destroy = function() end }
    assert.has_no.errors(function() Tag.unlink_and_destroy(tag) end)
    -- Already destroyed
    tag.chart_tag = nil
    assert.has_no.errors(function() Tag.unlink_and_destroy(tag) end)
    -- Nil tag
    assert.has_no.errors(function() Tag.unlink_and_destroy(nil) end)
  end)

  it("teleport_player_with_messaging covers vehicle/driving/riding edge cases", function()
    local tag = Tag.new("1.2.1")
    local player = make_player(1)
    player.driving = true
    player.vehicle = { teleport = function() return true end }
    player.riding_state = 1
    _G.defines = { riding = { acceleration = { nothing = 0 } } }
    -- Not nothing, should error
    player.riding_state = 2
    local result = Tag.teleport_player_with_messaging(player, {x=0,y=0}, make_surface(1))
    assert(type(result) == "string" and result:find("prohibited"))
    -- Nothing, should succeed
    player.riding_state = 0
    player.teleport = function() return true end
    local res = Tag.teleport_player_with_messaging(player, {x=0,y=0}, make_surface(1))
    assert(res == Constants.enums.return_state.SUCCESS)
  end)
end)

describe("Tag 100% coverage missed branches", function()
  local Tag = require("core.tag.tag")
  local make_player = require("tests.mocks.mock_player")
  local make_surface = require("tests.mocks.mock_surface")
  local Constants = require("constants")
  local BLANK_GPS = "1000000.1000000.1"

  it("get_chart_tag returns cached value if already set", function()
    local tag = Tag.new("1.2.1")
    tag.chart_tag = { foo = "bar" }
    assert.same(tag.chart_tag, tag:get_chart_tag())
  end)

  it("is_player_favorite returns false for missing faved_by_players", function()
    local tag = Tag.new("1.2.1")
    tag.faved_by_players = nil
    local player = make_player(1)
    assert.is_false(tag:is_player_favorite(player))
  end)

  it("is_owner returns false for missing chart_tag or player.name", function()
    local tag = Tag.new("1.2.1")
    tag.chart_tag = { last_user = "TestPlayer" }
    local player = make_player(1)
    player.name = nil
    assert.is_false(tag:is_owner(player))
  end)

  it("add_faved_by_player errors for non-number", function()
    local tag = Tag.new("1.2.1")
    assert.has_error(function() tag:add_faved_by_player("foo") end)
  end)

  it("remove_faved_by_player does nothing if not present", function()
    local tag = Tag.new("1.2.1", {2,3})
    tag:remove_faved_by_player(1)
    assert.same({2,3}, tag.faved_by_players)
  end)

  it("teleport_player_with_messaging returns error for missing character", function()
    local tag = Tag.new("1.2.1")
    local player = make_player(1)
    player.character = nil
    local pos = {x=0, y=0}
    local surface = make_surface(1)
    local result = Tag.teleport_player_with_messaging(player, pos, surface)
    assert(type(result) == "string" and result:find("character is missing"))
  end)

  it("teleport_player_with_messaging returns fallback error if teleport fails", function()
    local tag = Tag.new("1.2.1")
    local player = make_player(1)
    player.teleport = function() return false end
    local pos = {x=0, y=0}
    local surface = make_surface(1)
    local result = Tag.teleport_player_with_messaging(player, pos, surface)
    assert(type(result) == "string" and result:find("unable to perform the teleport"))
  end)
end)
