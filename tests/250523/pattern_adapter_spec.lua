-- tests/250523/test_pattern_adapter.lua
-- EmmyLua @type strict
-- Test suite for core/pattern/adapter.lua
local assert = require("luassert")
local busted = require("busted")
local describe = busted.describe
local it = busted.it
local Adapter = require("core.pattern.adapter")

describe("Adapter", function()
  it("should adapt interface", function()
    local adaptee = { foo = function() return "bar" end }
    local adapter = setmetatable({}, { __index = adaptee })
    assert.are.equal(adapter:foo(), "bar")
  end)
end)
