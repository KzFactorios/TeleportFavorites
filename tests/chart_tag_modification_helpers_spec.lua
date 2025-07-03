-- tests/events/chart_tag_modification_helpers_spec.lua

if not _G.storage then _G.storage = {} end
local ModHelpers = require("core.events.chart_tag_modification_helpers")

describe("ChartTagModificationHelpers", function()
    it("should be a table/module", function()
        assert.is_table(ModHelpers)
    end)
    -- Add more tests for exported functions as needed
end)
