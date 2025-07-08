-- tests/fave_bar_combined_spec.lua
-- Combined test suite for FaveBar, FaveBarGuiLabelsManager, and ControlFaveBar

if not _G.storage then _G.storage = {} end
local FaveBar = require("gui.favorites_bar.fave_bar")
local LabelsManager = require("core.control.fave_bar_gui_labels_manager")
local ControlFaveBar = require("core.control.control_fave_bar")

describe("FaveBar", function()
    it("should be a table/module", function()
        assert.is_table(FaveBar)
    end)
    -- Add more tests for exported functions as needed
end)

describe("FaveBarGuiLabelsManager", function()
    it("should be a table/module", function()
        assert.is_table(LabelsManager)
    end)
    -- Add more tests for exported functions as needed
end)

describe("ControlFaveBar", function()
    it("should be a table/module", function()
        assert.is_table(ControlFaveBar)
    end)
    -- Add more tests for exported functions as needed
end)
