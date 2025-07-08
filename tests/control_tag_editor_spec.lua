-- tests/control/control_tag_editor_spec.lua

require("tests.test_bootstrap")
if not _G.storage then _G.storage = {} end
local TagEditor = require("core.control.control_tag_editor")

describe("TagEditor", function()
    it("should be a table/module", function()
        assert.is_table(TagEditor)
    end)
    -- Add more tests for exported functions as needed
end)
