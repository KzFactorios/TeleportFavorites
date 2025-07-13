require("test_bootstrap") -- Ensure test bootstrap is loaded first for global mocks

-- tests/events/player_controller_handler_spec.lua

if not _G.storage then _G.storage = {} end
local PlayerControllerHandler = require("core.events.player_controller_handler")
local spy_utils = require("mocks.spy_utils")
local make_spy = spy_utils.make_spy

describe("PlayerControllerHandler", function()
    it("should be a table/module", function()
        assert.is_table(PlayerControllerHandler)
    end)
    -- Add more tests for exported functions as needed
end)
