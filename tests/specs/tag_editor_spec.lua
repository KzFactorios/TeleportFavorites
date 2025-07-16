require("test_bootstrap")

-- tests/tag_editor_combined_spec.lua
-- Combined and deduplicated tests for tag editor and event helpers

if not _G.storage then _G.storage = {} end
if not _G.global then _G.global = {} end
if not _G.defines then _G.defines = {render_mode = {chart = 1, game = 0}} end
if not _G.settings then _G.settings = {get_player_settings = function() return { ["show-player-coords"] = {value = true} } end} end
if not _G.game then _G.game = { print = function() end, players = {}, surfaces = { [1] = { index = 1, name = "nauvis", valid = true, get_tile = function(x, y) return { name = "grass-1", valid = true, collides_with = function(type) return false end } end } }, forces = { player = { name = "player", index = 1, find_chart_tags = function() return {} end } } } end

-- Basic TagEditor module test
local TagEditor = require("gui.tag_editor.tag_editor")
describe("TagEditor (GUI)", function()
    it("should be a table/module", function()
        assert.is_table(TagEditor)
    end)
    -- Add more tests for exported functions as needed
end)

-- Robust event helpers tests (from busted-compatible file)
local Mocks = require("mocks.tag_editor_mocks")
package.loaded["core.cache.cache"] = Mocks.Cache
package.loaded["core.utils.chart_tag_spec_builder"] = Mocks.ChartTagSpecBuilder
package.loaded["core.utils.chart_tag_utils"] = Mocks.ChartTagUtils
package.loaded["core.utils.gps_utils"] = Mocks.GPSUtils
package.loaded["core.utils.position_utils"] = Mocks.PositionUtils
package.loaded["core.cache.settings_cache"] = Mocks.Settings
package.loaded["core.tag.tag_destroy_helper"] = Mocks.tag_destroy_helper
package.loaded["prototypes.enums.enum"] = Mocks.Enum
package.loaded["core.utils.basic_helpers"] = Mocks.basic_helpers

local spy_utils = require("mocks.spy_utils")
local make_spy = spy_utils.make_spy

local function create_valid_player(render_mode)
  return {
    index = 1,
    name = "test_player",
    valid = true,
    render_mode = render_mode or defines.render_mode.chart,
    force = game.forces.player,
    surface = game.surfaces[1],
    gui = { screen = {} },
    print = function(msg) end
  }
end

local function create_chart_tag(position, surface)
  return {
    position = position or {x = 100, y = 100},
    surface = surface or game.surfaces[1],
    text = "Test Chart Tag",
    valid = true,
    destroy = function() end,
    force = game.forces.player
  }
end

describe("TagEditorEventHelpers", function()
  it("should be a table/module", function()
    -- Mock Cache module before requiring TagEditorEventHelpers
    package.loaded["core.cache.cache"] = {
      get_player_data = function() return {} end,
      is_modal_dialog_active = function() return false end,
      get_modal_dialog_type = function() return nil end
    }
    
    local TagEditorEventHelpers = require("core.events.tag_editor_event_helpers")
    assert.is_table(TagEditorEventHelpers)
  end)
  -- Add more robust event helper tests as needed, using mocks
end)
