-- tests/250523/test_tag_sync.lua
-- EmmyLua @type strict
-- Test suite for core/tag/tag_sync.lua
local assert = require("luassert")
local busted = require("busted")
local describe = busted.describe
local it = busted.it
local TagSync = require("core.tag.tag_sync")
local Tag = require("core.tag.tag")

describe("TagSync", function()
  it("should construct with a Tag instance", function()
    local tag = Tag:new("foo")
    local sync = TagSync:new(tag)
    assert.are.equal(sync.tag, tag)
  end)
end)
