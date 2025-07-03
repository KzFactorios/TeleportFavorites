-- tests/gui/favorites_bar/fave_bar_spec.lua

if not _G.storage then _G.storage = {} end
local FaveBar = require("gui.favorites_bar.fave_bar")

describe("FaveBar", function()
    it("should be a table/module", function()
        assert.is_table(FaveBar)
    end)
    -- Add more tests for exported functions as needed
end)
