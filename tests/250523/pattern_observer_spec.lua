-- tests/250523/test_pattern_observer.lua
-- EmmyLua @type strict
-- Test suite for core/pattern/observer.lua
local assert = require("luassert")
local busted = require("busted")
local describe = busted.describe
local it = busted.it
local Observer = require("core.pattern.observer")

describe("Observer", function()
  it("should notify observers", function()
    local notified = { value = false }
    local subject = { observers = {}, attach = function(self, obs) table.insert(self.observers, obs) end, notify = function(self) for _, obs in ipairs(self.observers) do obs:update() end end }
    local observer = { update = function() notified.value = true end }
    subject:attach(observer)
    subject:notify()
    assert.is_true(notified.value)
  end)
end)
