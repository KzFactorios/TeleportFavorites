require("test_bootstrap")
-- tests/events/on_gui_closed_handler_spec.lua

if not _G.storage then _G.storage = {} end
local OnGuiClosedHandler = require("core.events.on_gui_closed_handler")
local spy_utils = require("mocks.spy_utils")
local make_spy = spy_utils.make_spy

describe("OnGuiClosedHandler", function()
    it("should be a table/module", function()
        assert.is_table(OnGuiClosedHandler)
    end)
    -- Add more tests for exported functions as needed
end)
