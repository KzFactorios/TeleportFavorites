-- tests/250523/test_pattern_singleton.lua
-- EmmyLua @type strict
-- Test suite for core/pattern/singleton.lua
local assert = require("luassert")
local busted = require("busted")
local describe = busted.describe
local it = busted.it
local Singleton = require("core.pattern.singleton")

describe("Singleton", function()
  it("should return the same instance", function()
    local s1 = Singleton:getInstance()
    local s2 = Singleton:getInstance()
    assert.are.equal(s1, s2)
  end)
end)
