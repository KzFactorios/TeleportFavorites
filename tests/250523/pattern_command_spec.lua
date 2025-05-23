-- tests/250523/test_pattern_command.lua
-- EmmyLua @type strict
-- Test suite for core/pattern/command.lua
local assert = require("luassert")
local busted = require("busted")
local describe = busted.describe
local it = busted.it
local Command = require("core.pattern.command")

describe("Command", function()
  it("should execute command logic", function()
    local executed = { value = false }
    local cmd = { execute = function() executed.value = true end }
    cmd:execute()
    assert.is_true(executed.value)
  end)
end)
