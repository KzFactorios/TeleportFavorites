-- tests/250523/test_pattern_facade.lua
-- EmmyLua @type strict
-- Test suite for core/pattern/facade.lua
local assert = require("luassert")
local busted = require("busted")
local describe = busted.describe
local it = busted.it
local Facade = require("core.pattern.facade")

describe("Facade", function()
  it("should provide a simplified interface", function()
    local subsystem = { foo = function() return 42 end }
    local facade = setmetatable({}, { __index = subsystem })
    assert.are.equal(facade:foo(), 42)
  end)
end)
