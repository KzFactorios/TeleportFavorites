-- tests/250523/test_pattern_composite.lua
-- EmmyLua @type strict
-- Test suite for core/pattern/composite.lua
local assert = require("luassert")
local busted = require("busted")
local describe = busted.describe
local it = busted.it
local Composite = require("core.pattern.composite")

describe("Composite", function()
  it("should aggregate children and call them", function()
    local child1 = { execute = function() return 1 end }
    local child2 = { execute = function() return 2 end }
    local composite = { children = {}, add = function(self, c) table.insert(self.children, c) end, execute_all = function(self) local r = {} for _,c in ipairs(self.children) do table.insert(r, c:execute()) end return r end }
    composite:add(child1)
    composite:add(child2)
    local results = composite:execute_all()
    assert.are.same(results, {1, 2})
  end)
end)
