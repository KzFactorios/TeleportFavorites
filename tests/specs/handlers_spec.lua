-- tests/handlers_spec.lua
-- Test suite for core.events.handlers

require("test_framework")
require("test_bootstrap")

if not _G.storage then _G.storage = {} end

describe("Handlers", function()
    it("should be a table/module", function()
        local Handlers = require("core.events.handlers")
        is_true(type(Handlers) == "table", "Handlers should be a table")
    end)
end)
