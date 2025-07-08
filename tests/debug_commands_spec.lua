-- tests/commands/debug_commands_spec.lua
-- Minimal smoke test for debug_commands registration

require("tests.test_bootstrap")
if not _G.storage then _G.storage = {} end
local DebugCommands = require("core.commands.debug_commands")

describe("DebugCommands", function()
    it("should have a register_commands function", function()
        assert.is_function(DebugCommands.register_commands)
    end)
    -- Add more tests as needed for command registration
end)
