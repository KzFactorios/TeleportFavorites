-- tests/events/chart_tag_removal_helpers_spec.lua

if not _G.storage then _G.storage = {} end
local RemovalHelpers = require("core.events.chart_tag_removal_helpers")

describe("ChartTagRemovalHelpers", function()
    it("should be a table/module", function()
        assert.is_table(RemovalHelpers)
    end)
    -- Add more tests for exported functions as needed
end)
