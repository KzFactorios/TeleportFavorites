-- tests/events/event_registration_dispatcher_spec.lua

if not _G.storage then _G.storage = {} end
local EventReg = require("core.events.event_registration_dispatcher")

describe("EventRegistrationDispatcher", function()
    it("should be a table/module", function()
        assert.is_table(EventReg)
    end)
    -- Add more tests for exported functions as needed
end)
