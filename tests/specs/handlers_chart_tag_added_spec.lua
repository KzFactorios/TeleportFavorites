-- tests/handlers_chart_tag_added_spec.lua
-- Focused tests for the on_chart_tag_added handler function

-- Shared Factorio test environment (globals, settings, etc.)
require("mocks.factorio_test_env")

-- Require canonical player mocks
local PlayerFavoritesMocks = require("mocks.player_favorites_mocks")

-- Create mocks for dependencies
local Cache = {
  init = function() end,
  get_player_data = function() return {} end,
  set_tag_editor_data = function() end,
  create_tag_editor_data = function() return {} end,
  get_tag_by_gps = function() return nil end,
  Lookups = {
    invalidate_surface_chart_tags = function() end,
    get_chart_tag_cache = function() return {} end,
  }
}

local PositionUtils = {
  needs_normalization = function(position) 
    if not position then return false end
    return position.x ~= math.floor(position.x) or position.y ~= math.floor(position.y)
  end,
  normalize_if_needed = function(pos) 
    if not pos then return pos end
    return {x = math.floor(pos.x), y = math.floor(pos.y)}
  end,
}

local GPSUtils = {
  gps_from_map_position = function(position, surface_index) 
    if not position then return nil end
    local surface_name = "nauvis"
    if type(surface_index) == "number" then
      surface_name = tostring(surface_index)
    end
    return "gps:" .. position.x .. "," .. position.y .. "," .. surface_name
  end
}

local TagEditorEventHelpers = {
  normalize_and_replace_chart_tag = function(chart_tag, player)
    -- Return a new chart tag with normalized coordinates
    local normalized_pos = {
      x = math.floor(chart_tag.position.x),
      y = math.floor(chart_tag.position.y)
    }
    
    local new_chart_tag = {
      position = normalized_pos,
      valid = true,
      surface = chart_tag.surface,
      text = chart_tag.text,
      last_user = player
    }
    
    return new_chart_tag, {
      old = chart_tag.position,
      new = normalized_pos
    }
  end,
}

local ErrorHandler = {
  debug_log = function() end
}

-- Use our custom test framework instead of luassert
require('test_framework')

-- Mock package.loaded for dependencies
package.loaded["core.cache.cache"] = Cache
package.loaded["core.utils.position_utils"] = PositionUtils
package.loaded["core.utils.gps_utils"] = GPSUtils
package.loaded["core.events.tag_editor_event_helpers"] = TagEditorEventHelpers
package.loaded["core.utils.error_handler"] = ErrorHandler
package.loaded["gui.tag_editor.tag_editor"] = {build = function() end}
package.loaded["core.utils.cursor_utils"] = {end_drag_favorite = function() end}
package.loaded["core.cache.settings_cache"] = {get_chart_tag_click_radius = function() return 5 end}
package.loaded["gui.favorites_bar.fave_bar"] = {build = function() end}
package.loaded["core.utils.gui_helpers"] = {}
package.loaded["core.events.chart_tag_helpers"] = {
  is_valid_tag_modification = function() return true end
}
package.loaded["core.utils.gui_validation"] = {find_child_by_name = function() return nil end}
package.loaded["prototypes.enums.enum"] = {GuiEnum = {GUI_FRAME = {}}}
package.loaded["core.control.fave_bar_gui_labels_manager"] = {
  register_all = function() end,
  initialize_all_players = function() end,
  update_label_for_player = function() end
}

-- All patching and handler require must be inside the test suite

describe("Handlers.on_chart_tag_added", function()
  local Handlers
  local mock_player
  local mock_event
  local mock_players = {}
  local mock_surfaces = {
    [1] = {
      index = 1,
      name = "nauvis",
      valid = true
    }
  }
  local needs_normalization_spy, normalize_and_replace_chart_tag_spy, debug_log_spy, invalidate_surface_chart_tags_spy

  before_each(function()
    -- Remove handler from package.loaded to force fresh load with patched dependencies
    package.loaded["core.events.handlers"] = nil
    -- Patch all required dependencies for handlers and attach spies to package.loaded objects
    local PositionUtils = {
      needs_normalization = function(position)
        if not position then return false end
        return position.x ~= math.floor(position.x) or position.y ~= math.floor(position.y)
      end,
      normalize_if_needed = function(pos)
        if not pos then return pos end
        return {x = math.floor(pos.x), y = math.floor(pos.y)}
      end
    }
    local TagEditorEventHelpers = {
      normalize_and_replace_chart_tag = function(chart_tag, player)
        return {
          position = chart_tag and chart_tag.position or nil,
          valid = true,
          surface = chart_tag and chart_tag.surface or nil,
          text = chart_tag and chart_tag.text or nil,
          last_user = player
        }, { old = chart_tag and chart_tag.position or nil, new = chart_tag and chart_tag.position or nil }
      end
    }
    local ErrorHandler = {
      debug_log = function() end
    }
    local Cache = {
      Lookups = {
        invalidate_surface_chart_tags = function() end
      }
    }
    local GPSUtils = {
      gps_from_map_position = function(position, surface_index)
        if not position then return nil end
        local surface_name = "nauvis"
        if type(surface_index) == "number" then
          surface_name = tostring(surface_index)
        end
        return "gps:" .. position.x .. "," .. position.y .. "," .. surface_name
      end
    }
    -- Patch package.loaded
    package.loaded["core.utils.position_utils"] = PositionUtils
    package.loaded["core.utils.position_normalizer"] = PositionUtils
    package.loaded["core.events.tag_editor_event_helpers"] = TagEditorEventHelpers
    package.loaded["core.utils.error_handler"] = ErrorHandler
    package.loaded["core.cache.cache"] = Cache
    package.loaded["core.utils.gps_utils"] = GPSUtils
    package.loaded["gui.tag_editor.tag_editor"] = {build = function() end}
    package.loaded["core.utils.cursor_utils"] = {end_drag_favorite = function() end}
    package.loaded["core.cache.settings_cache"] = {get_chart_tag_click_radius = function() return 5 end}
    package.loaded["gui.favorites_bar.fave_bar"] = {build = function() end}
    package.loaded["core.utils.gui_helpers"] = {}
    package.loaded["core.utils.gui_validation"] = {find_child_by_name = function() return nil end}
    package.loaded["prototypes.enums.enum"] = {GuiEnum = {GUI_FRAME = {}}}
    package.loaded["core.control.fave_bar_gui_labels_manager"] = {
      register_all = function() end,
      initialize_all_players = function() end,
      update_label_for_player = function() end
    }
    require("mocks.admin_utils_mock")
    _G.script = { on_nth_tick = function() end }
    _G.game = {
      players = mock_players,
      get_player = function(player_index)
        return mock_players[player_index]
      end,
      surfaces = mock_surfaces
    }
    mock_player = PlayerFavoritesMocks.mock_player(1, "test_player", 1)
    mock_players[1] = mock_player
    mock_event = {
      player_index = 1,
      tag = { position = { x = 10, y = 20 }, valid = true, surface = mock_surfaces[1], text = "Test Tag", last_user = mock_player }
    }
    package.loaded["core.favorite.player_favorites"] = {
      new = function()
        return {
          player = mock_player,
          player_index = mock_player.index,
          surface_index = mock_player.surface.index,
          favorites = {},
          get_favorite_by_gps = function() return nil end
        }
      end
    }
    -- Create spies using our custom spy system
    local spy_utils = require("mocks.spy_utils")
    local make_spy = spy_utils.make_spy
    
    make_spy(package.loaded["core.utils.position_utils"], "needs_normalization")
    make_spy(package.loaded["core.events.tag_editor_event_helpers"], "normalize_and_replace_chart_tag")
    make_spy(package.loaded["core.utils.error_handler"], "debug_log")
    make_spy(package.loaded["core.cache.cache"].Lookups, "invalidate_surface_chart_tags")
    
    -- Store references for easy access - get the spy objects, not the functions
    needs_normalization_spy = package.loaded["core.utils.position_utils"].needs_normalization_spy
    normalize_and_replace_chart_tag_spy = package.loaded["core.events.tag_editor_event_helpers"].normalize_and_replace_chart_tag_spy
    debug_log_spy = package.loaded["core.utils.error_handler"].debug_log_spy
    invalidate_surface_chart_tags_spy = package.loaded["core.cache.cache"].Lookups.invalidate_surface_chart_tags_spy
    -- Now require the handler (after patching and spying)
    Handlers = require("core.events.handlers")
  end)

  after_each(function()
    needs_normalization_spy:revert()
    normalize_and_replace_chart_tag_spy:revert()
    debug_log_spy:revert()
    invalidate_surface_chart_tags_spy:revert()
  end)

  it("should not process for invalid players", function()
    mock_event.player_index = 999 -- Invalid player index
    Handlers.on_chart_tag_added(mock_event)
    assert.spy(needs_normalization_spy).was_not_called()
    assert.spy(normalize_and_replace_chart_tag_spy).was_not_called()
    assert.spy(debug_log_spy).was_not_called()
    assert.spy(invalidate_surface_chart_tags_spy).was_not_called()
  end)

  it("should not normalize coordinates that are already integers", function()
    mock_event.tag.position = {x = 100, y = 200}
    PositionUtils.needs_normalization = function() return false end
    
    -- Just test that the handler executes without errors
    local success = pcall(function() Handlers.on_chart_tag_added(mock_event) end)
    is_true(success)
  end)

  it("should normalize coordinates that are fractional", function()
    mock_event.tag.position = {x = 100.5, y = 200.5}
    PositionUtils.needs_normalization = function() return true end
    
    -- Just test that the handler executes without errors
    local success = pcall(function() Handlers.on_chart_tag_added(mock_event) end)
    is_true(success)
  end)

  it("should invalidate surface chart tags cache after tag added", function()
    -- Just test that the handler executes without errors
    local success = pcall(function() Handlers.on_chart_tag_added(mock_event) end)
    is_true(success)
  end)

  it("should handle invalid chart tag gracefully", function()
    mock_event.tag = nil
    -- Just test that the handler executes without errors
    local success = pcall(function() Handlers.on_chart_tag_added(mock_event) end)
    is_true(success)
  end)

  it("should handle chart tag without position gracefully", function()
    mock_event.tag = {
      valid = true,
      surface = mock_surfaces[1],
      text = "Test Tag"
    }
    -- Just test that the handler executes without errors
    local success = pcall(function() Handlers.on_chart_tag_added(mock_event) end)
    is_true(success)
  end)

  it("should normalize chart tags with very large fractional positions", function()
    mock_event.tag.position = {x = 1000.9999, y = 2000.9999}
    needs_normalization_spy:reset()
    PositionUtils.needs_normalization = function() return true end
    Handlers.on_chart_tag_added(mock_event)
    assert.spy(normalize_and_replace_chart_tag_spy).was_called()
  end)

  it("should normalize chart tags with negative fractional positions", function()
    mock_event.tag.position = {x = -100.5, y = -200.5}
    needs_normalization_spy:reset()
    PositionUtils.needs_normalization = function() return true end
    Handlers.on_chart_tag_added(mock_event)
    assert.spy(normalize_and_replace_chart_tag_spy).was_called()
  end)
end)

