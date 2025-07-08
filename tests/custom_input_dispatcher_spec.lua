-- tests/events/custom_input_dispatcher_spec.lua

require("tests.test_bootstrap")
if not _G.storage then _G.storage = {} end
local InputDispatcher = require("core.events.custom_input_dispatcher")

describe("CustomInputDispatcher", function()
    it("should be a table/module", function()
        assert.is_table(InputDispatcher)
    end)
    -- Add more tests for exported functions as needed
end)
