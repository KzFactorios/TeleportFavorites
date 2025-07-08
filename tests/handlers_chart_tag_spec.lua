local bootstrap = require("tests.test_bootstrap")
local Cache = bootstrap.Cache
local make_spy = bootstrap.make_spy
-- Focused tests for chart tag handlers in the handlers module

-- Mock global environment for tests
if not _G.storage then _G.storage = {} end
if not _G.global then _G.global = {} end
if not _G.defines then 
  _G.defines = {
    render_mode = {
      chart = 1,
      game = 2
    }
  }
end

-- Create mocks for dependencies
-- Use mocks from bootstrap
    if not x or not y then return nil end
    return x .. ", " .. y
  end,
  map_position_from_gps = function(gps)
    if not gps then return nil end
    local x, y = gps:match("gps:([%-%.%d]+),([%-%.%d]+)")
    if not x or not y then return nil end 
    return {x = tonumber(x), y = tonumber(y)}
  end,
}

local TagEditorEventHelpers = {
  validate_tag_editor_opening = function() return true end,
  find_nearby_chart_tag = function() return nil end,
  normalize_and_replace_chart_tag = function(chart_tag) 
    if not chart_tag or not chart_tag.valid then return nil, nil end
    
    local normalized_position = PositionUtils.normalize_if_needed(chart_tag.position)
    local new_chart_tag = {
      position = normalized_position,
      valid = true,
      surface = chart_tag.surface,
      text = chart_tag.text,
      last_user = chart_tag.last_user,
      destroy = function() end
    }
    
    return new_chart_tag, {
      old = chart_tag.position, 
      new = normalized_position
    }
  end
}

local ChartTagModificationHelpers = {
  is_valid_tag_modification = function() return true end,
  extract_gps = function(event, player) 
    if not event or not event.tag or not event.tag.position then return nil, nil end
    
    local new_position = event.tag.position
    local old_position = event.old_position
    local surface_index = event.tag.surface and event.tag.surface.index or 1
    
    local new_gps = GPSUtils.gps_from_map_position(new_position, surface_index)
    local old_gps = GPSUtils.gps_from_map_position(old_position, surface_index)
    
    return new_gps, old_gps
  end,
  update_tag_and_cleanup = function() end,
  update_favorites_gps = function() end,
}

local ErrorHandler = {
  debug_log = function() end
}

local GuiValidation = {
  find_child_by_name = function(parent, name)
    if name == "tag_editor_teleport_button" then
      return {
        valid = true,
        caption = {"", "Teleport to 100, 200"}
      }
    end
    if parent and name then
      return {
        valid = true
      }
    end
    return nil
  end
}

local Enum = {
  GuiEnum = {
    GUI_FRAME = {
      TAG_EDITOR = "tag_editor_frame"
    }
  }
}

-- Mock remaining dependencies
package.loaded["core.cache.cache"] = Cache
package.loaded["core.utils.position_utils"] = PositionUtils
package.loaded["core.utils.gps_utils"] = GPSUtils
package.loaded["core.events.tag_editor_event_helpers"] = TagEditorEventHelpers
package.loaded["core.events.chart_tag_modification_helpers"] = ChartTagModificationHelpers
package.loaded["core.utils.error_handler"] = ErrorHandler
package.loaded["core.utils.gui_validation"] = GuiValidation
package.loaded["prototypes.enums.enum"] = Enum

-- Other dependencies needed by handlers
package.loaded["core.utils.cursor_utils"] = {
  end_drag_favorite = function() end
}
package.loaded["core.utils.settings_access"] = {
  get_chart_tag_click_radius = function() return 5 end
}
package.loaded["core.favorite.player_favorites"] = {
  new = function(player)
    return {
      player = player or {},
      player_index = player and player.index or 1,
      surface_index = player and player.surface and player.surface.index or 1,
      favorites = {},
      get_favorite_by_gps = function(self, gps)
        return nil
      end
    }
  end
}
package.loaded["core.utils.gui_helpers"] = {}
package.loaded["gui.tag_editor.tag_editor"] = {
  build = function() end
}
package.loaded["gui.favorites_bar.fave_bar"] = {
  build = function() end
}
package.loaded["core.control.fave_bar_gui_labels_manager"] = {
  register_all = function() end,
  initialize_all_players = function() end,
  update_label_for_player = function() end,
  get_coords_caption = function() return {"", "100, 200"} end,
  get_history_caption = function() return {"", "History"} end
}

-- Mock game environment
local mock_players = {}
local mock_surfaces = {
  [1] = {
    index = 1,
    name = "nauvis",
    valid = true
  }
}

_G.script = {
  on_nth_tick = function() end
}

-- Create mock game global
_G.game = {
  players = mock_players,
  get_player = function(player_index)
    return mock_players[player_index]
  end,
  surfaces = mock_surfaces
}

-- Import the handlers module
local Handlers = require("core.events.handlers")

-- Patch: assign all mocks to _G for global access in tests
local function assign_mocks_to_globals()
  _G.Cache = Cache
  _G.PositionUtils = PositionUtils
  _G.GPSUtils = GPSUtils
  _G.TagEditorEventHelpers = TagEditorEventHelpers
  _G.ChartTagModificationHelpers = ChartTagModificationHelpers
  _G.ErrorHandler = ErrorHandler
  _G.GuiValidation = GuiValidation
  _G.Enum = Enum
end

-- Table to track all active spies for cleanup
local active_spies = {}

-- Minimal custom spy implementation for this test file
local spy = {
  on = function(obj, method_name)
    local original = obj[method_name]
    local s = { calls = {} }
    s.wrapper = function(...)
      table.insert(s.calls, {...})
      return original(...)
    end
    obj[method_name] = s.wrapper
    s.revert = function()
      obj[method_name] = original
    end
    table.insert(active_spies, s)
    return s
  end
}

describe("Chart Tag Handlers", function()
  -- Setup before each test
  before_each(function()
    -- Assign all mocks to _G for global access
    assign_mocks_to_globals()
    -- Reset our mocks
    mock_players = {}
    
    -- Set up players
    mock_players[1] = {
      index = 1,
      name = "player1",
      valid = true,
      surface = mock_surfaces[1],
      gui = {
        screen = {}
      },
      play_sound = function() end,
      print = function() end
    }

    -- Set up spies on all helper functions that are expected to be called
    spy.on(TagEditorEventHelpers, "normalize_and_replace_chart_tag")
    spy.on(ChartTagModificationHelpers, "update_tag_and_cleanup")
    spy.on(ChartTagModificationHelpers, "update_favorites_gps")
    spy.on(ErrorHandler, "debug_log")
  end)
  
  -- Clean up after each test
  after_each(function()
    -- Revert all spies and clear the table
    for _, s in ipairs(active_spies) do
      if s.revert then s.revert() end
    end
    active_spies = {}
    -- Optionally, clear _G of mocks if needed
    _G.Cache = nil
    _G.PositionUtils = nil
    _G.GPSUtils = nil
    _G.TagEditorEventHelpers = nil
    _G.ChartTagModificationHelpers = nil
    _G.ErrorHandler = nil
    _G.GuiValidation = nil
    _G.Enum = nil
  end)
  
  it("should handle chart tag added event correctly", function()
    local TagEditorEventHelpers = require("core.events.tag_editor_event_helpers")
    local ErrorHandler = require("core.utils.error_handler")
    -- Manual spy for normalize_and_replace_chart_tag
    local norm_spy_calls = {}
    TagEditorEventHelpers.normalize_and_replace_chart_tag = function(...)
      table.insert(norm_spy_calls, {...})
    end
    -- Manual spy for debug_log
    local log_spy_calls = {}
    ErrorHandler.debug_log = function(...)
      table.insert(log_spy_calls, {...})
    end
    local event = {
      player_index = 1,
      tag = {
        valid = true,
        position = {x = 100.5, y = 200.5}, -- Fractional position
        surface = mock_surfaces[1]
      }
    }
    Handlers.on_chart_tag_added(event)
    assert(#norm_spy_calls > 0)
    assert(#log_spy_calls > 0)
  end)

  it("should not normalize chart tag with integer positions", function()
    local TagEditorEventHelpers = require("core.events.tag_editor_event_helpers")
    local norm_spy_calls = {}
    TagEditorEventHelpers.normalize_and_replace_chart_tag = function(...)
      table.insert(norm_spy_calls, {...})
    end
    local event = {
      player_index = 1,
      tag = {
        valid = true,
        position = {x = 100, y = 200}, -- Integer position
        surface = mock_surfaces[1]
      }
    }
    Handlers.on_chart_tag_added(event)
    assert(#norm_spy_calls == 0)
    norm_spy.revert()
  end)

  it("should handle chart tag modification correctly with normalization", function()
    local TagEditorEventHelpers = require("core.events.tag_editor_event_helpers")
    local ChartTagModificationHelpers = require("core.events.chart_tag_modification_helpers")
    local norm_spy_calls = {}
    TagEditorEventHelpers.normalize_and_replace_chart_tag = function(...)
      table.insert(norm_spy_calls, {...})
    end
    local update_tag_spy_calls = {}
    ChartTagModificationHelpers.update_tag_and_cleanup = function(...)
      table.insert(update_tag_spy_calls, {...})
    end
    local update_fav_spy_calls = {}
    ChartTagModificationHelpers.update_favorites_gps = function(...)
      table.insert(update_fav_spy_calls, {...})
    end
    local event = {
      player_index = 1,
      tag = {
        valid = true,
        position = {x = 100.5, y = 200.5}, -- Fractional position
        surface = mock_surfaces[1],
        text = "Test Tag"
      },
      old_position = {x = 90, y = 180}
    }
    PositionUtils.needs_normalization = function() return true end
    Handlers.on_chart_tag_modified(event)
    assert(#norm_spy_calls > 0)
    assert(#update_tag_spy_calls > 0)
    assert(#update_fav_spy_calls > 0)
    norm_spy.revert()
    update_tag_spy.revert()
    update_fav_spy.revert()
  end)

  it("should handle chart tag modification correctly without normalization", function()
    local TagEditorEventHelpers = require("core.events.tag_editor_event_helpers")
    local ChartTagModificationHelpers = require("core.events.chart_tag_modification_helpers")
    local norm_spy_calls = {}
    TagEditorEventHelpers.normalize_and_replace_chart_tag = function(...)
      table.insert(norm_spy_calls, {...})
    end
    local update_tag_spy_calls = {}
    ChartTagModificationHelpers.update_tag_and_cleanup = function(...)
      table.insert(update_tag_spy_calls, {...})
    end
    local update_fav_spy_calls = {}
    ChartTagModificationHelpers.update_favorites_gps = function(...)
      table.insert(update_fav_spy_calls, {...})
    end
    local event = {
      player_index = 1,
      tag = {
        valid = true,
        position = {x = 100, y = 200}, -- Integer position
        surface = mock_surfaces[1],
        text = "Test Tag"
      },
      old_position = {x = 90, y = 180}
    }
    PositionUtils.needs_normalization = function() return false end
    Handlers.on_chart_tag_modified(event)
    assert(#norm_spy_calls == 0)
    assert(#update_tag_spy_calls > 0)
    assert(#update_fav_spy_calls > 0)
    norm_spy.revert()
    update_tag_spy.revert()
    update_fav_spy.revert()
  end)

  it("should update tag_editor data when chart tag is modified", function()
    local set_data_spy_calls = {}
    Cache.set_tag_editor_data = function(...)
      table.insert(set_data_spy_calls, {...})
    end
    Handlers.on_chart_tag_modified(event)
    assert(#set_data_spy_calls > 0)
    local original_gps = "gps:90,180,nauvis"
    local new_gps = "gps:100,200,nauvis"
    Cache.get_tag_editor_data = function()
      return {
        gps = original_gps,
        tag = { gps = original_gps }
      }
    end
    ChartTagModificationHelpers.extract_gps = function()
      return new_gps, original_gps
    end
    mock_players[1].gui.screen["tag_editor_frame"] = {
      valid = true,
      ["tag_editor_teleport_button"] = {
        valid = true,
        caption = {"", "Teleport to 90, 180"}
      }
    }
    GuiValidation.find_child_by_name = function(parent, name)
      if name == "tag_editor_frame" then
        return mock_players[1].gui.screen["tag_editor_frame"]
      elseif name == "tag_editor_teleport_button" then
        return mock_players[1].gui.screen["tag_editor_frame"]["tag_editor_teleport_button"]
      end
      return nil
    end
    local event = {
      player_index = 1,
      tag = {
        valid = true,
        position = {x = 100, y = 200},
        surface = mock_surfaces[1],
        text = "Test Tag"
      },
      old_position = {x = 90, y = 180}
    }
    Handlers.on_chart_tag_modified(event)
    assert(#set_data_spy.calls > 0)
    set_data_spy.revert()
  end)
  
  it("should handle invalid player in chart tag events", function()
    local event = {
      player_index = 999, -- Non-existent player
      tag = {
        valid = true,
        position = {x = 100, y = 200},
        surface = mock_surfaces[1]
      }
    }
    
    -- These should not error even with invalid player
    Handlers.on_chart_tag_added(event)
    Handlers.on_chart_tag_modified(event)
    Handlers.on_chart_tag_removed(event)
  end)
  
  -- Edge case: event.tag is missing in on_chart_tag_added
  it("should do nothing if event.tag is missing in on_chart_tag_added", function()
    local norm_spy = spy.on(TagEditorEventHelpers, "normalize_and_replace_chart_tag")
    local log_spy = spy.on(ErrorHandler, "debug_log")
    local event = { player_index = 1, tag = nil }
    Handlers.on_chart_tag_added(event)
    assert(#norm_spy.calls == 0)
    assert(#log_spy.calls == 0)
    norm_spy.revert()
    log_spy.revert()
  end)

  -- Edge case: event.tag is invalid in on_chart_tag_added
  it("should do nothing if event.tag is invalid in on_chart_tag_added", function()
    local norm_spy = spy.on(TagEditorEventHelpers, "normalize_and_replace_chart_tag")
    local log_spy = spy.on(ErrorHandler, "debug_log")
    local event = { player_index = 1, tag = { valid = false, position = {x=1, y=2}, surface = mock_surfaces[1] } }
    Handlers.on_chart_tag_added(event)
    assert(#norm_spy.calls == 0)
    assert(#log_spy.calls == 0)
    norm_spy.revert()
    log_spy.revert()
  end)

  -- Edge case: event.tag.position is missing in on_chart_tag_added
  it("should do nothing if event.tag.position is missing in on_chart_tag_added", function()
    local norm_spy = spy.on(TagEditorEventHelpers, "normalize_and_replace_chart_tag")
    local log_spy = spy.on(ErrorHandler, "debug_log")
    local event = { player_index = 1, tag = { valid = true, position = nil, surface = mock_surfaces[1] } }
    Handlers.on_chart_tag_added(event)
    assert(#norm_spy.calls == 0)
    assert(#log_spy.calls == 0)
    norm_spy.revert()
    log_spy.revert()
  end)

  -- Edge case: event.old_position is missing in on_chart_tag_modified
  it("should do nothing if event.old_position is missing in on_chart_tag_modified", function()
    local norm_spy = spy.on(TagEditorEventHelpers, "normalize_and_replace_chart_tag")
    local update_tag_spy = spy.on(ChartTagModificationHelpers, "update_tag_and_cleanup")
    local update_fav_spy = spy.on(ChartTagModificationHelpers, "update_favorites_gps")
    local event = { player_index = 1, tag = { valid = true, position = {x=100, y=200}, surface = mock_surfaces[1], text = "Test Tag" }, old_position = nil }
    Handlers.on_chart_tag_modified(event)
    assert(#norm_spy.calls == 0)
    assert(#update_tag_spy.calls == 0)
    assert(#update_fav_spy.calls == 0)
    norm_spy.revert()
    update_tag_spy.revert()
    update_fav_spy.revert()
  end)

  -- Edge case: event.tag is missing in on_chart_tag_modified
  it("should do nothing if event.tag is missing in on_chart_tag_modified", function()
    local norm_spy = spy.on(TagEditorEventHelpers, "normalize_and_replace_chart_tag")
    local update_tag_spy = spy.on(ChartTagModificationHelpers, "update_tag_and_cleanup")
    local update_fav_spy = spy.on(ChartTagModificationHelpers, "update_favorites_gps")
    local event = { player_index = 1, tag = nil, old_position = {x=90, y=180} }
    Handlers.on_chart_tag_modified(event)
    assert(#norm_spy.calls == 0)
    assert(#update_tag_spy.calls == 0)
    assert(#update_fav_spy.calls == 0)
    norm_spy.revert()
    update_tag_spy.revert()
    update_fav_spy.revert()
  end)

  -- Edge case: event.tag.position is missing in on_chart_tag_modified
  it("should do nothing if event.tag.position is missing in on_chart_tag_modified", function()
    local norm_spy = spy.on(TagEditorEventHelpers, "normalize_and_replace_chart_tag")
    local update_tag_spy = spy.on(ChartTagModificationHelpers, "update_tag_and_cleanup")
    local update_fav_spy = spy.on(ChartTagModificationHelpers, "update_favorites_gps")
    local event = { player_index = 1, tag = { valid = true, position = nil, surface = mock_surfaces[1], text = "Test Tag" }, old_position = {x=90, y=180} }
    Handlers.on_chart_tag_modified(event)
    assert(#norm_spy.calls == 0)
    assert(#update_tag_spy.calls == 0)
    assert(#update_fav_spy.calls == 0)
    norm_spy.revert()
    update_tag_spy.revert()
    update_fav_spy.revert()
  end)

  -- Edge case: player is invalid in on_chart_tag_modified
  it("should do nothing if player is invalid in on_chart_tag_modified", function()
    local norm_spy = spy.on(TagEditorEventHelpers, "normalize_and_replace_chart_tag")
    local update_tag_spy = spy.on(ChartTagModificationHelpers, "update_tag_and_cleanup")
    local update_fav_spy = spy.on(ChartTagModificationHelpers, "update_favorites_gps")
    local event = { player_index = 999, tag = { valid = true, position = {x=100, y=200}, surface = mock_surfaces[1], text = "Test Tag" }, old_position = {x=90, y=180} }
    Handlers.on_chart_tag_modified(event)
    assert(#norm_spy.calls == 0)
    assert(#update_tag_spy.calls == 0)
    assert(#update_fav_spy.calls == 0)
    norm_spy.revert()
    update_tag_spy.revert()
    update_fav_spy.revert()
  end)
end)
