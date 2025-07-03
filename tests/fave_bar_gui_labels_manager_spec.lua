-- tests/control/fave_bar_gui_labels_manager_spec.lua

if not _G.storage then _G.storage = {} end
local LabelsManager = require("core.control.fave_bar_gui_labels_manager")

describe("FaveBarGuiLabelsManager", function()
    it("should be a table/module", function()
        assert.is_table(LabelsManager)
    end)
    -- Add more tests for exported functions as needed
end)
