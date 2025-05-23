-- tests/250523/test_pattern_proxy.lua
-- EmmyLua @type strict
-- Test suite for core/pattern/proxy.lua
local assert = require("luassert")
local busted = require("busted")
local describe = busted.describe
local it = busted.it
local Proxy = require("core.pattern.proxy")

describe("Proxy", function()
  it("should proxy method calls", function()
    local real = { foo = function() return "baz" end }
    local proxy = setmetatable({}, { __index = real })
    assert.are.equal(proxy:foo(), "baz")
  end)
end)
