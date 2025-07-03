-- tests/gui/data_viewer/data_viewer_gui_builders_spec.lua
local DataViewerGuiBuilders = require("gui.data_viewer.data_viewer_gui_builders")

describe("DataViewerGuiBuilders", function()
    it("should be a table/module", function()
        assert.is_table(DataViewerGuiBuilders)
    end)
    -- Add more tests for exported functions as needed
end)
