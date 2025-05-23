-- tests/250523/test_tag.lua
-- EmmyLua @type strict
-- Test suite for core/tag/tag.lua
local assert = require("luassert")
local busted = require("busted")
local describe = busted.describe
local it = busted.it
local Tag = require("core.tag.tag")

describe("Tag", function()
  it("should create a tag with correct fields", function()
    local tag = Tag:new("foo", {1,2})
    assert.are.equal(tag.gps, "foo")
    assert.are.same(tag.faved_by_players, {1,2})
  end)

  it("should add a player to faved_by_players", function()
    local tag = Tag:new("foo")
    tag:add_faved_by_player(3)
    local found = false
    for _, v in ipairs(tag.faved_by_players) do if v == 3 then found = true end end
    assert.is_true(found)
  end)
end)
