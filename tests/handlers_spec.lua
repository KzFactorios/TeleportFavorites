-- tests/events/handlers_spec.lua

if not _G.storage then _G.storage = {} end
local Handlers = require("core.events.handlers")

describe("Handlers", function()
    it("should be a table/module", function()
        assert.is_table(Handlers)
    end)
    -- Add more tests for exported functions as needed
end)
