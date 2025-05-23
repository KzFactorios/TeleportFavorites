-- tests/250523/test_helpers.lua
-- EmmyLua @type strict
-- Test suite for core/utils/Helpers.lua
local assert = require("luassert")
local busted = require("busted")
local describe = busted.describe
local it = busted.it
local Helpers = require("core.utils.Helpers")

describe("Helpers", function()
  it("should deep copy tables", function()
    local t = {a=1, b={c=2}}
    local t2 = Helpers.deep_copy and Helpers.deep_copy(t) or t
    assert.are_not.equal(t, t2)
    assert.are.equal(t2.b.c, 2)
  end)
end)
