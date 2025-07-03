-- tests/gui/tag_editor/tag_editor_spec.lua

if not _G.storage then _G.storage = {} end
local TagEditor = require("gui.tag_editor.tag_editor")

describe("TagEditor (GUI)", function()
    it("should be a table/module", function()
        assert.is_table(TagEditor)
    end)
    -- Add more tests for exported functions as needed
end)
