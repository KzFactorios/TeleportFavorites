-- tests/control/control_data_viewer_spec.lua

if not _G.storage then _G.storage = {} end
local DataViewer = require("core.control.control_data_viewer")

describe("DataViewer", function()
    it("should have an on_toggle_data_viewer function", function()
        assert.is_function(DataViewer.on_toggle_data_viewer)
    end)
    it("should have an on_data_viewer_gui_click function", function()
        assert.is_function(DataViewer.on_data_viewer_gui_click)
    end)
    it("should have a register function", function()
        assert.is_function(DataViewer.register)
    end)
    -- Add more tests for GUI event handling as needed
end)
