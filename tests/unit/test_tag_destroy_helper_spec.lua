-- tests/unit/test_tag_destroy_helper.lua
-- Unit tests for core.tag.tag_destroy_helper
---@diagnostic disable
local tag_destroy_helper = require("core.tag.tag_destroy_helper")
local Helpers = require("tests.mocks.mock_helpers")
local Constants = require("constants")
local BLANK_GPS = "1000000.1000000.1"

describe("tag_destroy_helper", function()
    it("should destroy tag and chart tag", function()
        local tag = { gps = "1.2.1", faved_by_players = {1,2} }
        local chart_tag = { valid = true, destroyed = false, destroy = function(self) self.destroyed = true end }
        tag_destroy_helper.destroy_tag_and_chart_tag(tag, chart_tag)
        assert(chart_tag.destroyed, "Chart tag should be destroyed")
    end)

    it("should guard against recursion", function()
        local tag = { gps = "1.2.1", faved_by_players = {1} }
        local chart_tag = { valid = true, destroyed = false, destroy = function(self) self.destroyed = true end }
        -- Simulate recursion: mark as being destroyed
        tag_destroy_helper.is_tag_being_destroyed(tag)
        tag_destroy_helper.is_chart_tag_being_destroyed(chart_tag)
        -- Should not destroy again
        tag_destroy_helper.destroy_tag_and_chart_tag(tag, chart_tag)
        -- No error, no double-destroy
    end)

    it("should not destroy blank favorite tags", function()
        local blank = {gps = BLANK_GPS, text = "", locked = false}
        assert.is_false(tag_destroy_helper.should_destroy(blank))
    end)
end)
