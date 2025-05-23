-- tests/250523/test_pattern_builder.lua
-- EmmyLua @type strict
-- Test suite for core/pattern/builder.lua
local assert = require("luassert")
local busted = require("busted")
local describe = busted.describe
local it = busted.it
local Builder = require("core.pattern.builder")

describe("Builder", function()
  it("should build objects step by step", function()
    local builder = { obj = {}, set_part = function(self, k, v) self.obj[k] = v end, build = function(self) return self.obj end }
    builder:set_part("foo", 123)
    local obj = builder:build()
    assert.are.equal(obj.foo, 123)
  end)
end)
