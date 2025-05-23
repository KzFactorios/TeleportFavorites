-- tests/250523/test_pattern_strategy.lua
-- EmmyLua @type strict
-- Test suite for core/pattern/strategy.lua
local assert = require("luassert")
local busted = require("busted")
local describe = busted.describe
local it = busted.it
local Strategy = require("core.pattern.strategy")

describe("Strategy", function()
  it("should switch strategies", function()
    local stratA = { execute = function() return "A" end }
    local stratB = { execute = function() return "B" end }
    local context = { strategy = stratA, execute = function(self) return self.strategy:execute() end, set_strategy = function(self, s) self.strategy = s end }
    assert.are.equal(context:execute(), "A")
    context:set_strategy(stratB)
    assert.are.equal(context:execute(), "B")
  end)
end)
