-- tests/250523/test_lookups.lua
-- EmmyLua @type strict
-- Test suite for core/cache/lookups.lua
local assert = require("luassert")
local busted = require("busted")
local describe = busted.describe
local it = busted.it
local Lookups = require("core.cache.lookups")

describe("Lookups", function()
  it("should set and get values", function()
    Lookups.set("bar", 456)
    assert.are.equal(Lookups.get("bar"), 456)
  end)

  it("should remove values", function()
    Lookups.set("bar", 456)
    Lookups.remove("bar")
    assert.is_nil(Lookups.get("bar"))
  end)
end)
