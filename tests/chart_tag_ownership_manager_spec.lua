-- tests/control/chart_tag_ownership_manager_spec.lua

if not _G.storage then _G.storage = {} end
local ChartTagOwnershipManager = require("core.control.chart_tag_ownership_manager")

describe("ChartTagOwnershipManager", function()
    it("should have a reset_ownership_for_player function", function()
        assert.is_function(ChartTagOwnershipManager.reset_ownership_for_player)
    end)
    it("should have an on_player_left_game function", function()
        assert.is_function(ChartTagOwnershipManager.on_player_left_game)
    end)
    it("should have an on_player_removed function", function()
        assert.is_function(ChartTagOwnershipManager.on_player_removed)
    end)
    -- Add more tests for event handling as needed
end)
