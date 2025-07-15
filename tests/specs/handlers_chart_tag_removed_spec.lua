-- tests/handlers_chart_tag_removed_spec.lua
-- Tests for the on_chart_tag_removed handler function

-- Shared Factorio test environment (globals, settings, etc.)
require("mocks.factorio_test_env")

-- Require canonical player mocks and shared spy utility
local PlayerFavoritesMocks = require("mocks.player_favorites_mocks")
local spy_utils = require("mocks.spy_utils")
local make_spy = spy_utils.make_spy

-- Create minimal mocks for dependencies
package.loaded["core.cache.cache"] = {
  init = function() end,
  Lookups = {
    invalidate_surface_chart_tags = function() end
  }
}
package.loaded["core.utils.position_utils"] = {}
package.loaded["core.utils.gps_utils"] = {}
package.loaded["core.utils.error_handler"] = {debug_log = function() end}
package.loaded["core.utils.cursor_utils"] = {}
package.loaded["gui.tag_editor.tag_editor"] = {}
package.loaded["core.events.tag_editor_event_helpers"] = {}
package.loaded["core.cache.settings_cache"] = {}
package.loaded["core.favorite.player_favorites"] = {
  new = function(player)
    return {
      player = player or mock_players[1],
      player_index = (player and player.index) or 1,
      surface_index = (player and player.surface and player.surface.index) or 1,
      favorites = {},
      get_favorite_by_gps = function() return nil end
    }
  end
}
package.loaded["core.utils.gui_validation"] = {}
package.loaded["core.utils.gui_helpers"] = {}
package.loaded["gui.favorites_bar.fave_bar"] = {}
package.loaded["prototypes.enums.enum"] = {}
package.loaded["core.control.fave_bar_gui_labels_manager"] = {
  register_all = function() end,
  initialize_all_players = function() end,
}
package.loaded["core.events.chart_tag_helpers"] = {}

-- Mock game environment
local mock_players = {}

before_each(function()
  mock_players[1] = PlayerFavoritesMocks.mock_player(1, "test_player", 1)
end)

-- Import the module under test
local Handlers = require("core.events.handlers")

describe("Handlers.on_chart_tag_removed", function()
  before_each(function()
    mock_players[1] = PlayerFavoritesMocks.mock_player(1, "test_player", 1)
  end)
  
  it("should have on_chart_tag_removed function", function()
    assert(type(Handlers.on_chart_tag_removed) == "function", 
      "Handlers should have on_chart_tag_removed function")
  end)
  
  it("should accept an event parameter", function()
    -- This is a no-op currently, but we should still test it exists
    local event = {
      player_index = 1,
      tag = {
        position = {x = 100, y = 200},
        valid = true,
        surface = {index = 1},
        text = "Test Tag"
      }
    }
    
    -- Should run without errors
    local success, error = pcall(function() 
      Handlers.on_chart_tag_removed(event) 
    end)
    
    assert(success, "on_chart_tag_removed should run without errors: " .. (error or ""))
  end)
end)
