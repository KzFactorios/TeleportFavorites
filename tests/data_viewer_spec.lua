-- tests/data_viewer_combined_spec.lua
-- Combined and deduplicated tests for DataViewer (GUI and control)

require("tests.test_bootstrap")
if not _G.storage then _G.storage = {} end

-- GUI DataViewer module
local DataViewerGUI = require("gui.data_viewer.data_viewer")
-- Control DataViewer module
local DataViewerControl = require("core.control.control_data_viewer")
local mock_player_data = require("tests.mocks.mock_player_data")

describe("DataViewer (GUI)", function()
    it("should be a table/module", function()
        assert.is_table(DataViewerGUI)
    end)
    it("should export required functions", function()
        assert.is_function(DataViewerGUI.build)
        assert.is_function(DataViewerGUI.update_content_panel)
        assert.is_function(DataViewerGUI.update_font_size)
        assert.is_function(DataViewerGUI.update_tab_selection)
        assert.is_function(DataViewerGUI.show_refresh_notification)
    end)
end)

describe("DataViewer (Control)", function()
    it("should have an on_toggle_data_viewer function", function()
        assert.is_function(DataViewerControl.on_toggle_data_viewer)
    end)
    it("should have an on_data_viewer_gui_click function", function()
        assert.is_function(DataViewerControl.on_data_viewer_gui_click)
    end)
    it("should have a register function", function()
        assert.is_function(DataViewerControl.register)
    end)
    -- Add more tests for GUI event handling as needed
end)

describe("Data Viewer per-player settings", function()
  it("should have default font size", function()
    local mock = mock_player_data.create_mock_player_data()
    local player = mock.players[1]
    assert.equals(player.data_viewer_settings.font_size, 12)
  end)
end)
