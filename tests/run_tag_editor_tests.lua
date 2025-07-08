-- Simple test harness for running consolidated tag_editor_event_helpers tests

-- Load the appropriate modules for testing
local Mocks = require("tests.mocks.tag_editor_mocks")

-- Setup package.loaded to return our mocks
package.loaded["core.cache.cache"] = Mocks.Cache
package.loaded["core.utils.chart_tag_spec_builder"] = Mocks.ChartTagSpecBuilder
package.loaded["core.utils.chart_tag_utils"] = Mocks.ChartTagUtils
package.loaded["core.utils.gps_utils"] = Mocks.GPSUtils
package.loaded["core.utils.position_utils"] = Mocks.PositionUtils
package.loaded["core.utils.settings_access"] = Mocks.Settings
package.loaded["core.tag.tag_destroy_helper"] = Mocks.tag_destroy_helper
package.loaded["prototypes.enums.enum"] = Mocks.Enum
package.loaded["core.utils.basic_helpers"] = Mocks.basic_helpers

-- Set up required globals
if not _G.game then
  _G.game = {
    -- print = function() end,
    players = {},
    surfaces = {
      [1] = {
        index = 1,
        name = "nauvis",
        valid = true,
        get_tile = function(x, y)
          return {
            name = "grass-1",
            valid = true,
            collides_with = function(type) return false end
          }
        end
      }
    },
    forces = {
      player = {
        name = "player",
        index = 1,
        find_chart_tags = function() return {} end
      }
    }
  }
end

if not _G.defines then
  _G.defines = {
    render_mode = {
      chart = 1,
      game = 0
    }
  }
end

-- Load the module to test
local TagEditorEventHelpers = require("core.events.tag_editor_event_helpers")

-- Setup test player
local function create_test_player()
  return {
    index = 1,
    name = "player",
    valid = true,
    render_mode = defines.render_mode.chart,
    force = _G.game.forces.player,
    surface = _G.game.surfaces[1],
    gui = {
      screen = {}
    }
  }
end

-- Run the tests
local function run_tests()
  -- print("Running tag_editor_event_helpers tests...")
  
  -- Test validate_tag_editor_opening
  local player = create_test_player()
  local can_open = TagEditorEventHelpers.validate_tag_editor_opening(player)
  -- print("validate_tag_editor_opening with valid player: " .. (can_open and "PASS" or "FAIL"))
  
  local invalid_player = { valid = false }
  can_open = TagEditorEventHelpers.validate_tag_editor_opening(invalid_player)
  -- print("validate_tag_editor_opening with invalid player: " .. (not can_open and "PASS" or "FAIL"))
  
  can_open = TagEditorEventHelpers.validate_tag_editor_opening(nil)
  -- print("validate_tag_editor_opening with nil player: " .. (not can_open and "PASS" or "FAIL"))
  
  -- Test find_nearby_chart_tag
  local position = {x = 100, y = 100}
  local surface_index = 1
  local chart_tag = TagEditorEventHelpers.find_nearby_chart_tag(position, surface_index, 5)
  -- print("find_nearby_chart_tag returns nil when no tags: " .. (chart_tag == nil and "PASS" or "FAIL"))
  
  -- Test create_temp_tag_gps
  local gps = TagEditorEventHelpers.create_temp_tag_gps(position, player, surface_index)
  -- print("create_temp_tag_gps creates GPS string: " .. (gps ~= nil and "PASS" or "FAIL"))
  
  -- Test normalize_and_replace_chart_tag
  local chart_tag_with_position = {
    position = {x = 100.5, y = 100.5},
    valid = true,
    surface = game.surfaces[1],
    force = game.forces.player,
    destroy = function() end
  }
  
  local new_chart_tag, position_pair = TagEditorEventHelpers.normalize_and_replace_chart_tag(chart_tag_with_position, player)
  -- print("normalize_and_replace_chart_tag normalizes position: " .. (new_chart_tag ~= nil and "PASS" or "FAIL"))
  
  -- print("\nAll tests completed.")
end

run_tests()
