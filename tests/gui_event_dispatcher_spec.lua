require("tests.test_bootstrap")
-- tests/events/gui_event_dispatcher_spec.lua

if not _G.storage then _G.storage = {} end
local GuiEventDispatcher = require("core.events.gui_event_dispatcher")

describe("GuiEventDispatcher", function()
    it("should be a table/module", function()
        assert.is_table(GuiEventDispatcher)
    end)
    -- Add more tests for exported functions as needed
end)
