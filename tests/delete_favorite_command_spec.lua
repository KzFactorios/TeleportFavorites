-- tests/commands/delete_favorite_command_spec.lua
-- Minimal smoke test for delete_favorite_command registration

require("tests.test_bootstrap")
if not _G.storage then _G.storage = {} end
local DeleteFavoriteCommand = require("core.commands.delete_favorite_command")

describe("DeleteFavoriteCommand", function()
    it("should have a register_commands function", function()
        assert.is_function(DeleteFavoriteCommand.register_commands)
    end)
    -- Add more tests as needed for command registration
end)
