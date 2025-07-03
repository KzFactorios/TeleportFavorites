-- tests/gui/data_viewer/data_viewer_spec.lua

if not _G.storage then _G.storage = {} end
local DataViewer = require("gui.data_viewer.data_viewer")

describe("DataViewer (GUI)", function()
    it("should be a table/module", function()
        assert.is_table(DataViewer)
    end)
    -- Add more tests for exported functions as needed
end)
