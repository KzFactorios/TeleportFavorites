-- tests/events/tag_editor_event_helpers_spec.lua

if not _G.storage then _G.storage = {} end
local TagEditorEventHelpers = require("core.events.tag_editor_event_helpers")

describe("TagEditorEventHelpers", function()
    it("should be a table/module", function()
        assert.is_table(TagEditorEventHelpers)
    end)
    -- Add more tests for exported functions as needed
end)
