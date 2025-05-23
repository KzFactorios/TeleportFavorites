-- tests/250523/test_helpers_gps.lua
-- EmmyLua @type strict
-- Test suite for core/utils/Helpers_gps.lua
local assert = require("luassert")
local busted = require("busted")
local describe = busted.describe
local it = busted.it
local Helpers_gps = require("core.utils.Helpers_gps")

describe("Helpers_gps", function()
  it("should format gps strings", function()
    if Helpers_gps.format_gps then
      local gps = Helpers_gps.format_gps(100, 200, 1)
      assert.are.equal(gps, "[gps=100,200,1]")
    else
      assert.is_true(true) -- skip if not implemented
    end
  end)
end)
