-- tests/250523/test_cache.lua
-- EmmyLua @type strict
-- Test suite for core/cache/cache.lua

local assert = require("luassert")
local Cache = require("core.cache.cache")
local busted = require("busted")
local describe = busted.describe
local it = busted.it

describe("Cache", function()
  it("should store and retrieve values", function()
    Cache.set("foo", 123)
    assert.are.equal(Cache.get("foo"), 123)
  end)

  it("should remove values", function()
    Cache.set("foo", 123)
    Cache.remove("foo")
    assert.is_nil(Cache.get("foo"))
  end)
end)
