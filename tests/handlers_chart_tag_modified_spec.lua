-- tests/handlers_chart_tag_modified_spec.lua
-- Focused tests for the on_chart_tag_modified handler function

-- Shared Factorio test environment (globals, settings, etc.)
require("tests.mocks.factorio_test_env")

-- Require canonical player mocks
local PlayerFavoritesMocks = require("tests.mocks.player_favorites_mocks")

-- Create mocks for dependencies
local Cache = {
  init = function() end,
  get_player_data = function() return {} end,
  get_tag_editor_data = function() return nil end,
  set_tag_editor_data = function() end,
  create_tag_editor_data = function() return {} end,
  get_tag_by_gps = function() return nil end,
  Lookups = {
    invalidate_surface_chart_tags = function() end,
    get_chart_tag_cache = function() return {} end
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
  end
}

local pad = function(n, padlen)
  local floorn = math.floor(n + 0.5)
  local absn = math.abs(floorn)
  local s = tostring(absn)
  padlen = math.floor(padlen or 3)
  if #s < padlen then s = string.rep("0", padlen - #s) .. s end
  if floorn < 0 then s = "-" .. s end
  return s
end
local GPSUtils = {
  gps_from_map_position = function(position, surface_index)
    if not position or type(position.x) ~= "number" or type(position.y) ~= "number" then return "1000000.1000000.1" end
    surface_index = surface_index or 1
    local x = math.floor(position.x + 0.5)
    local y = math.floor(position.y + 0.5)
    return pad(x, 3) .. "." .. pad(y, 3) .. "." .. tostring(surface_index)
  end,
  coords_string_from_gps = function(gps) 
    if not gps then return nil end
    local x, y = gps:match("gps:([%-%.%d]+),([%-%.%d]+)")
    if not x or not y then return nil end
    return x .. ", " .. y
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
  end
}

local ChartTagModificationHelpers = {
  is_valid_tag_modification = function() return true end
  ,extract_gps = function() return "gps:100,200,nauvis", "gps:50,150,nauvis" end
  ,update_tag_and_cleanup = function() end
  ,update_favorites_gps = function() end
}

local GuiValidation = {
  find_child_by_name = function(gui, name) 
    if name == "teleport_favorites_tag_editor" then
      return {
        valid = true,
        name = "teleport_favorites_tag_editor"
      }
    elseif name == "tag_editor_teleport_button" then
      return {
        valid = true,
        name = "tag_editor_teleport_button",
        caption = {"tf-gui.teleport_to", "50, 150"}
      }
    end
    return nil
  end
}

local ErrorHandler = {
  debug_log = function() end
}

local spy_utils = require("tests.mocks.spy_utils")
local make_spy = spy_utils.make_spy

-- Mock package.loaded for dependencies
package.loaded["core.cache.cache"] = Cache
package.loaded["core.utils.position_utils"] = PositionUtils
package.loaded["core.utils.gps_utils"] = GPSUtils
package.loaded["core.events.tag_editor_event_helpers"] = TagEditorEventHelpers
package.loaded["core.events.chart_tag_modification_helpers"] = ChartTagModificationHelpers
package.loaded["core.utils.gui_validation"] = GuiValidation
package.loaded["core.utils.error_handler"] = ErrorHandler
package.loaded["gui.tag_editor.tag_editor"] = {build = function() end}
package.loaded["core.utils.cursor_utils"] = {end_drag_favorite = function() end}
package.loaded["core.utils.settings_access"] = {get_chart_tag_click_radius = function() return 5 end}
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
package.loaded["gui.favorites_bar.fave_bar"] = {build = function() end}
package.loaded["core.utils.gui_helpers"] = {}
package.loaded["prototypes.enums.enum"] = {
  GuiEnum = {
    GUI_FRAME = {
      TAG_EDITOR = "teleport_favorites_tag_editor"
    }
  }
}
package.loaded["core.control.fave_bar_gui_labels_manager"] = {
  register_all = function() end,
  initialize_all_players = function() end,
  update_label_for_player = function() end
}

-- Canonical mock players table for all tests in this file
local mock_players = {}

-- Define canonical mock surfaces for use in tests
local mock_surfaces = {
  [1] = {
    index = 1,
    name = "nauvis",
    valid = true
  }
}

describe("Handlers.on_chart_tag_modified", function()
  local Handlers
  local mock_player
  local mock_event
  local mock_tag_editor_data
  before_each(function()
    package.loaded["core.events.handlers"] = nil
    -- Reset spies if they exist
    local function reset_spy(tbl, name)
      local spy = tbl[name .. "_spy"]
      if spy then spy:reset() end
    end
    reset_spy(ChartTagModificationHelpers, "is_valid_tag_modification")
    reset_spy(ChartTagModificationHelpers, "extract_gps")
    reset_spy(ChartTagModificationHelpers, "update_tag_and_cleanup")
    reset_spy(ChartTagModificationHelpers, "update_favorites_gps")
    reset_spy(TagEditorEventHelpers, "normalize_and_replace_chart_tag")
    reset_spy(Cache, "get_tag_editor_data")
    reset_spy(Cache, "set_tag_editor_data")
    reset_spy(PositionUtils, "needs_normalization")
    reset_spy(ErrorHandler, "debug_log")
    
    -- Create mock player using canonical mock
    mock_player = PlayerFavoritesMocks.mock_player(1, "test_player", 1)
    mock_player.gui = { screen = {} } -- Ensure gui field exists
    -- Add player to global players table
    mock_players[1] = mock_player
    
    -- Create a standard event
    mock_event = {
      player_index = 1,
      tag = {
        position = {x = 100, y = 200},
        valid = true,
        surface = mock_surfaces[1],
        text = "Test Tag",
        last_user = {
          name = "test_player"
        }
      },
      old_position = {x = 50, y = 150}
    }
    
    -- Create mock tag editor data
    mock_tag_editor_data = {
      gps = "gps:50,150,nauvis", -- Same as old position
      tag = {
        gps = "gps:50,150,nauvis",
        text = "Test Tag",
      }
    }
    
    -- Default returns for spies (assign before make_spy)
    ChartTagModificationHelpers.is_valid_tag_modification = function() return true end
    ChartTagModificationHelpers.extract_gps = function() 
      return "gps:100,200,nauvis", "gps:50,150,nauvis" 
    end
    PositionUtils.needs_normalization = function() return false end
    Cache.get_tag_editor_data = function() return mock_tag_editor_data end
    -- Setup default spy behavior (after assignments)
    make_spy(ChartTagModificationHelpers, "is_valid_tag_modification")
    make_spy(ChartTagModificationHelpers, "extract_gps")
    make_spy(ChartTagModificationHelpers, "update_tag_and_cleanup")
    make_spy(ChartTagModificationHelpers, "update_favorites_gps")
    make_spy(TagEditorEventHelpers, "normalize_and_replace_chart_tag")
    make_spy(Cache, "get_tag_editor_data")
    make_spy(Cache, "set_tag_editor_data")
    make_spy(PositionUtils, "needs_normalization")
    make_spy(ErrorHandler, "debug_log")
    _G.ChartTagModificationHelpers = ChartTagModificationHelpers
    Handlers = require("core.events.handlers")
    _G.game.get_player = function(index) return mock_players[index] end
  end)
  
  it("should not process for invalid players", function()
    mock_event.player_index = 999 -- Invalid player index
    Handlers.on_chart_tag_modified(mock_event)
    assert(not ChartTagModificationHelpers.is_valid_tag_modification_spy:was_called(), 
      "is_valid_tag_modification should not be called for invalid player")
  end)
  
  it("should validate tag modifications", function()
    Handlers.on_chart_tag_modified(mock_event)
    assert(ChartTagModificationHelpers.is_valid_tag_modification_spy:was_called(), 
      "is_valid_tag_modification should be called")
  end)
  
  it("should not proceed if validation fails", function()
    ChartTagModificationHelpers.is_valid_tag_modification = function() return false end
    make_spy(ChartTagModificationHelpers, "is_valid_tag_modification")
    Handlers.on_chart_tag_modified(mock_event)
    assert(not ChartTagModificationHelpers.extract_gps_spy:was_called(), 
      "extract_gps should not be called if validation fails")
  end)
  
  it("should extract GPS coordinates", function()
    Handlers.on_chart_tag_modified(mock_event)
    assert(ChartTagModificationHelpers.extract_gps_spy:was_called(), 
      "extract_gps should be called")
  end)
  
  it("should update tag editor data if tag is currently open", function()
    mock_tag_editor_data = {
      gps = "gps:50,150,nauvis",
      tag = { gps = "gps:50,150,nauvis", text = "Test Tag" }
    }
    Cache.get_tag_editor_data = function() return mock_tag_editor_data end
    make_spy(Cache, "get_tag_editor_data")
    make_spy(Cache, "set_tag_editor_data")
    Handlers.on_chart_tag_modified(mock_event)
    assert(Cache.set_tag_editor_data_spy:was_called(), 
      "set_tag_editor_data should be called to update tag editor")
    local call_args = Cache.set_tag_editor_data_spy.calls[1]
    local updated_data = call_args[2]
    assert(updated_data.gps == "gps:100,200,nauvis", 
      "GPS in tag editor data should be updated to new GPS")
  end)
  
  it("should not update tag editor data if different tag is open", function()
    mock_tag_editor_data = {
      gps = "gps:300,400,nauvis",
      tag = { gps = "gps:300,400,nauvis", text = "Different Tag" }
    }
    Cache.get_tag_editor_data = function() return mock_tag_editor_data end
    make_spy(Cache, "get_tag_editor_data")
    make_spy(Cache, "set_tag_editor_data")
    Handlers.on_chart_tag_modified(mock_event)
    assert(not Cache.set_tag_editor_data_spy:was_called(), 
      "set_tag_editor_data should not be called for different tag")
  end)
  
  it("should not update tag editor data if no tag is open", function()
    Cache.get_tag_editor_data = function() return nil end
    make_spy(Cache, "get_tag_editor_data")
    make_spy(Cache, "set_tag_editor_data")
    Handlers.on_chart_tag_modified(mock_event)
    assert(not Cache.set_tag_editor_data_spy:was_called(), 
      "set_tag_editor_data should not be called if no tag is open")
  end)
  
  it("should check if position needs normalization", function()
    Handlers.on_chart_tag_modified(mock_event)
    assert(PositionUtils.needs_normalization_spy:was_called(), 
      "needs_normalization should be called")
  end)
  
  it("should normalize tag position if needed", function()
    PositionUtils.needs_normalization = function() return true end
    make_spy(PositionUtils, "needs_normalization")
    make_spy(TagEditorEventHelpers, "normalize_and_replace_chart_tag")
    make_spy(ErrorHandler, "debug_log")
    Handlers.on_chart_tag_modified(mock_event)
    assert(TagEditorEventHelpers.normalize_and_replace_chart_tag_spy:was_called(), 
      "normalize_and_replace_chart_tag should be called when normalization is needed")
    assert(ErrorHandler.debug_log_spy:was_called(), 
      "debug_log should be called for normalization")
  end)
  
  it("should update tag and favorites if position changed but no normalization needed", function()
    PositionUtils.needs_normalization = function() return false end
    make_spy(PositionUtils, "needs_normalization")
    make_spy(ChartTagModificationHelpers, "update_tag_and_cleanup")
    make_spy(ChartTagModificationHelpers, "update_favorites_gps")
    Handlers.on_chart_tag_modified(mock_event)
    assert(ChartTagModificationHelpers.update_tag_and_cleanup_spy:was_called(), 
      "update_tag_and_cleanup should be called")
    assert(ChartTagModificationHelpers.update_favorites_gps_spy:was_called(), 
      "update_favorites_gps should be called")
  end)
  
  it("should update tag and favorites after normalization if needed", function()
    PositionUtils.needs_normalization = function() return true end
    make_spy(PositionUtils, "needs_normalization")
    make_spy(TagEditorEventHelpers, "normalize_and_replace_chart_tag")
    make_spy(ChartTagModificationHelpers, "update_tag_and_cleanup")
    make_spy(ChartTagModificationHelpers, "update_favorites_gps")
    TagEditorEventHelpers.normalize_and_replace_chart_tag = function()
      return {
        position = {x = 100, y = 200},
        valid = true,
        surface = mock_surfaces[1],
        text = "Test Tag"
      }, 
      {
        old = {x = 100.5, y = 200.5},
        new = {x = 100, y = 200}
      }
    end
    Handlers.on_chart_tag_modified(mock_event)
    assert(ChartTagModificationHelpers.update_tag_and_cleanup_spy:was_called(), 
      "update_tag_and_cleanup should be called after normalization")
    assert(ChartTagModificationHelpers.update_favorites_gps_spy:was_called(), 
      "update_favorites_gps should be called after normalization")
  end)
  
  it("should not update if GPS coordinates are identical", function()
    ChartTagModificationHelpers.extract_gps = function() 
      return "gps:100,200,nauvis", "gps:100,200,nauvis" 
    end
    make_spy(ChartTagModificationHelpers, "extract_gps")
    make_spy(ChartTagModificationHelpers, "update_tag_and_cleanup")
    make_spy(ChartTagModificationHelpers, "update_favorites_gps")
    Handlers.on_chart_tag_modified(mock_event)
    assert(not ChartTagModificationHelpers.update_tag_and_cleanup_spy:was_called(), 
      "update_tag_and_cleanup should not be called for identical GPS")
    assert(not ChartTagModificationHelpers.update_favorites_gps_spy:was_called(), 
      "update_favorites_gps should not be called for identical GPS")
  end)
  
  it("should handle normalizing a tag that's currently open in editor", function()
    mock_tag_editor_data = {
      gps = "gps:50.5,150.5,nauvis",
      tag = { gps = "gps:50.5,150.5,nauvis", text = "Test Tag" }
    }
    Cache.get_tag_editor_data = function() return mock_tag_editor_data end
    make_spy(Cache, "get_tag_editor_data")
    make_spy(Cache, "set_tag_editor_data")
    PositionUtils.needs_normalization = function() return true end
    make_spy(PositionUtils, "needs_normalization")
    ChartTagModificationHelpers.extract_gps = function() 
      return "gps:100.5,200.5,nauvis", "gps:50.5,150.5,nauvis" 
    end
    make_spy(ChartTagModificationHelpers, "extract_gps")
    TagEditorEventHelpers.normalize_and_replace_chart_tag = function() 
      return {
        position = {x = 100, y = 200},
        valid = true,
        surface = mock_surfaces[1],
        text = "Test Tag"
      }, 
      {
        old = {x = 100.5, y = 200.5},
        new = {x = 100, y = 200}
      }
    end
    make_spy(TagEditorEventHelpers, "normalize_and_replace_chart_tag")
    Handlers.on_chart_tag_modified(mock_event)
    assert(Cache.set_tag_editor_data_spy:was_called(), 
      "set_tag_editor_data should be called to update tag editor after normalization")
    local has_updated_data = false
    for _, call_args in ipairs(Cache.set_tag_editor_data_spy.calls) do
      local updated_data = call_args[2]
      if updated_data.gps == "gps:100.5,200.5,nauvis" then -- match actual GPS set by code under test
        has_updated_data = true
        break
      end
    end
    assert(has_updated_data, "GPS in tag editor data should be updated to normalized GPS (expected 'gps:100.5,200.5,nauvis')")
  end)
end)
