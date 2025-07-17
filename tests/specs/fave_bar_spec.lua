require("test_bootstrap")
-- tests/fave_bar_combined_spec.lua
-- Combined test suite for FaveBar and ControlFaveBar (FaveBarGuiLabelsManager removed)

if not _G.storage then _G.storage = {} end
local FaveBar = require("gui.favorites_bar.fave_bar")
local ControlFaveBar = require("core.control.control_fave_bar")

describe("FaveBar", function()
    it("should be a table/module", function()
        assert.is_table(FaveBar)
    end)
    -- Add more tests for exported functions as needed
end)
describe("ControlFaveBar", function()
    it("should be a table/module", function()
        assert.is_table(ControlFaveBar)
    end)
    -- Add more tests for exported functions as needed
end)
