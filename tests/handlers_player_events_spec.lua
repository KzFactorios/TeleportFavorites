-- Require canonical test bootstrap to patch all mocks before any SUT or test code
require("tests.test_bootstrap")

-- Shared Factorio test environment (globals, settings, etc.)
require("tests.mocks.factorio_test_env")

-- Require canonical player mocks
local PlayerFavoritesMocks = require("tests.mocks.player_favorites_mocks")

-- Create mocks for dependencies
local Cache = {
  init = function() end,
  reset_transient_player_states = function() end,
  get_player_data = function() return {} end,
  set_tag_editor_data = function() end,
  ensure_surface_cache = function() end,
  set_player_surface = function() end,
  get_tag_by_gps = function() return nil end,
  get_tag_editor_data = function() return {} end,
  create_tag_editor_data = function() return {} end, -- Added missing function
  Lookups = {
    ensure_surface_cache = function() end
  }
}

local FaveBarGuiLabelsManager = {
  register_all = function() end,
  initialize_all_players = function() end,
  update_label_for_player = function() end,
  get_coords_caption = function() return {"", "100, 200"} end,
  get_history_caption = function() return {"", "History"} end
}

local fave_bar = {
  build = function() end
}

-- Require the shared spy utility
local spy_utils = require("tests.mocks.spy_utils")
local make_spy = spy_utils.make_spy

-- Mock the modules that will be required
package.loaded["core.cache.cache"] = Cache
package.loaded["core.control.fave_bar_gui_labels_manager"] = FaveBarGuiLabelsManager
package.loaded["gui.favorites_bar.fave_bar"] = fave_bar

-- Other required modules
package.loaded["core.utils.position_utils"] = { needs_normalization = function() return false end }
package.loaded["core.utils.gps_utils"] = { 
  gps_from_map_position = function() return "gps:100,200,nauvis" end 
}
package.loaded["core.utils.error_handler"] = { debug_log = function() end }
package.loaded["core.utils.cursor_utils"] = { end_drag_favorite = function() end }
package.loaded["gui.tag_editor.tag_editor"] = { build = function() end }
package.loaded["core.events.tag_editor_event_helpers"] = {
  validate_tag_editor_opening = function() return true end,
  find_nearby_chart_tag = function() return nil end
}
package.loaded["core.utils.settings_access"] = { get_chart_tag_click_radius = function() return 5 end }
package.loaded["core.favorite.player_favorites"] = {
  new = function(player)
    return {
      player = player or { index = 1, surface = { index = 1 } },
      player_index = (player and player.index) or 1,
      surface_index = (player and player.surface and player.surface.index) or 1,
      favorites = {},
      get_favorite_by_gps = function() return nil end
    }
  end
}
package.loaded["core.utils.gui_validation"] = { find_child_by_name = function() return nil end }
package.loaded["core.utils.gui_helpers"] = {}
package.loaded["core.events.chart_tag_modification_helpers"] = {
  is_valid_tag_modification = function() return true end,
  extract_gps = function() return "gps:100,200,nauvis", "gps:50,150,nauvis" end,
  update_tag_and_cleanup = function() end,
  update_favorites_gps = function() end
}
package.loaded["prototypes.enums.enum"] = {
  GuiEnum = {
    GUI_FRAME = {
      TAG_EDITOR = "tag_editor_frame"
    }
  }
}

-- Mock game environment
local mock_surfaces = {
  [1] = {
    index = 1,
    name = "nauvis",
    valid = true
  }
}

_G.script = {
  on_nth_tick = function(_, callback) 
    -- Execute callback immediately for testing
    if callback then callback() end
    return true
  end
}

-- Create mock game global
_G.game = {
  players = {},
  get_player = function(player_index)
    return _G.game.players[player_index]
  end,
  surfaces = mock_surfaces
}

-- Import the handlers module
local Handlers = require("core.events.handlers")
package.loaded["core.events.handlers"] = Handlers

describe("Player Event Handlers", function()
  -- Setup before each test

before_each(function()
  -- Reset our mocks
  mock_players = {}
  -- Set up players using canonical mock
  mock_players[1] = PlayerFavoritesMocks.mock_player(1, "player1", 1)
  mock_players[2] = PlayerFavoritesMocks.mock_player(2, "player2", 1)

  -- Patch game.get_player to return our mock players
  if not _G.game then _G.game = {} end
  _G.game.get_player = function(idx) return mock_players[idx] end
  _G.game.players = mock_players

  -- Set up spies
  make_spy(Cache, "reset_transient_player_states")
  make_spy(fave_bar, "build")
  make_spy(FaveBarGuiLabelsManager, "register_all")
  make_spy(FaveBarGuiLabelsManager, "initialize_all_players")
  make_spy(FaveBarGuiLabelsManager, "update_label_for_player")

  -- Add spies for package.loaded mocks used in assertions
  local tag_editor = package.loaded["gui.tag_editor.tag_editor"]
  local cursor_utils = package.loaded["core.utils.cursor_utils"]
  make_spy(tag_editor, "build")
  make_spy(cursor_utils, "end_drag_favorite")

  -- Patch global and package.loaded TagEditorEventHelpers for all tests
  local default_helpers = {
    validate_tag_editor_opening = function() return true end,
    find_nearby_chart_tag = function() return nil end
  }
  package.loaded["core.events.tag_editor_event_helpers"] = default_helpers
  _G.TagEditorEventHelpers = default_helpers

  package.loaded["core.events.handlers"] = nil
  Handlers = require("core.events.handlers")
end)
  
  -- Clean up after each test
  after_each(function()
    Cache.reset_transient_player_states_spy:reset()
    Cache.reset_transient_player_states_spy:revert()
    fave_bar.build_spy:reset()
    fave_bar.build_spy:revert()
    FaveBarGuiLabelsManager.register_all_spy:reset()
    FaveBarGuiLabelsManager.register_all_spy:revert()
    FaveBarGuiLabelsManager.initialize_all_players_spy:reset()
    FaveBarGuiLabelsManager.initialize_all_players_spy:revert()
    FaveBarGuiLabelsManager.update_label_for_player_spy:reset()
    FaveBarGuiLabelsManager.update_label_for_player_spy:revert()
  end)

  it("should handle on_init correctly", function()
    -- Update game.players to have some players
    game.players = mock_players
    
    -- Call the handler
    Handlers.on_init()
    
    -- Verify correct functions were called
    assert(fave_bar.build_spy:was_called(), "fave_bar.build should be called")
    assert(FaveBarGuiLabelsManager.register_all_spy:was_called(), "FaveBarGuiLabelsManager.register_all should be called")
    assert(FaveBarGuiLabelsManager.initialize_all_players_spy:was_called(), "FaveBarGuiLabelsManager.initialize_all_players should be called")
  end)
  
  it("should handle on_load correctly", function()
    -- Call the handler
    Handlers.on_load()
    
    -- Verify correct functions were called
    assert(FaveBarGuiLabelsManager.register_all_spy:was_called(), "FaveBarGuiLabelsManager.register_all should be called")
    assert(FaveBarGuiLabelsManager.initialize_all_players_spy:was_called(), "FaveBarGuiLabelsManager.initialize_all_players should be called")
  end)
  
  it("should handle on_player_created correctly", function()
    local event = {
      player_index = 1
    }
    
    -- Call the handler
    Handlers.on_player_created(event)
    
    -- Verify correct functions were called
    assert(Cache.reset_transient_player_states_spy:call_count() > 0, "Cache.reset_transient_player_states should be called")
    assert(fave_bar.build_spy:was_called(), "fave_bar.build should be called")
    assert(FaveBarGuiLabelsManager.update_label_for_player_spy:call_count() >= 2, "FaveBarGuiLabelsManager.update_label_for_player should be called twice")
    
    -- Check if it was called with correct player
    local call_args = Cache.reset_transient_player_states_spy.calls[1]
    assert(mock_players[1] == call_args[1])
    call_args = fave_bar.build_spy.calls[1]
    assert(mock_players[1] == call_args[1])
  end)
  
  it("should handle on_player_joined_game correctly", function()
    local event = {
      player_index = 2
    }
    
    -- Call the handler
    Handlers.on_player_joined_game(event)
    
    -- Verify correct functions were called
    assert(fave_bar.build_spy:was_called(), "fave_bar.build should be called")
    assert(FaveBarGuiLabelsManager.update_label_for_player_spy:call_count() >= 2, "FaveBarGuiLabelsManager.update_label_for_player should be called twice")
    
    -- Check if it was called with correct player
    local call_args = fave_bar.build_spy.calls[1]
    assert(mock_players[2] == call_args[1])
  end)
  
  it("should handle invalid player gracefully", function()
    local event = {
      player_index = 999 -- Non-existent player
    }
    -- These should not error even with invalid player
    Handlers.on_player_created(event)
    Handlers.on_player_joined_game(event)
    -- No functions should be called with invalid player
    assert(Cache.reset_transient_player_states_spy:call_count() == 0)
    assert(fave_bar.build_spy:call_count() == 0)
  end)

  it("should handle on_open_tag_editor_custom_input with valid cursor position", function()
    -- Replace the entire tag_editor_event_helpers table for this test
    package.loaded["core.events.tag_editor_event_helpers"] = {
      find_nearby_chart_tag = function()
        return {
          valid = true,
          position = {x = 100, y = 200},
          surface = {index = 1},
          text = "Test Tag"
        }
      end
    }
    local tag_helpers = package.loaded["core.events.tag_editor_event_helpers"]
    -- Set up spies
    local tag_editor = package.loaded["gui.tag_editor.tag_editor"]
    local cursor_utils = package.loaded["core.utils.cursor_utils"]
    make_spy(tag_editor, "build")
    make_spy(Cache, "set_tag_editor_data")
    local event = {
      player_index = 1,
      cursor_position = {x = 100, y = 200}
    }
    -- Call the handler
    Handlers.on_open_tag_editor_custom_input(event)
    -- Verify tag_editor.build was called
    assert(tag_editor.build_spy:was_called(), "tag_editor.build should be called")
    assert(Cache.set_tag_editor_data_spy:was_called(), "Cache.set_tag_editor_data should be called")
    -- Clean up
    tag_editor.build_spy:reset()
    tag_editor.build_spy:revert()
    Cache.set_tag_editor_data_spy:reset()
    Cache.set_tag_editor_data_spy:revert()
  end)

  it("should handle on_open_tag_editor_custom_input with invalid tag editor opening", function()
    -- Replace the entire tag_editor_event_helpers table for this test
    local fake_helpers = {
      validate_tag_editor_opening = function()
        return false, "Drag mode active"
      end,
      find_nearby_chart_tag = function() return nil end
    }
    package.loaded["core.events.tag_editor_event_helpers"] = fake_helpers
    _G.TagEditorEventHelpers = fake_helpers

    -- Re-require the handler to ensure it picks up the new mocks
    package.loaded["core.events.handlers"] = nil
    Handlers = require("core.events.handlers")

    -- Set up spy on CursorUtils after all mocks
    local cursor_utils = package.loaded["core.utils.cursor_utils"]
    make_spy(cursor_utils, "end_drag_favorite")

    local event = {
      player_index = 1,
      cursor_position = {x = 100, y = 200}
    }
    -- Call the handler
    Handlers.on_open_tag_editor_custom_input(event)
    -- Verify end_drag_favorite was called
    assert(cursor_utils.end_drag_favorite_spy:was_called(), "end_drag_favorite should be called")
    -- Clean up
    cursor_utils.end_drag_favorite_spy:reset()
    cursor_utils.end_drag_favorite_spy:revert()
  end)
end)
