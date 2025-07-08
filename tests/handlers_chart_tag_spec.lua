
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

local PositionUtils = {
  needs_normalization = function(position)
    print("[MOCK] PositionUtils.needs_normalization called with:", position and position.x, position and position.y)
    if not position then return false end
    if math.floor(position.x) ~= position.x or math.floor(position.y) ~= position.y then
      return true
    end
    return false
  end,
  normalize_if_needed = function(position)
    print("[MOCK] PositionUtils.normalize_if_needed called with:", position and position.x, position and position.y)
    if not position then return nil end
    return { x = math.floor(position.x), y = math.floor(position.y) }
  end
}

local GPSUtils = {
  gps_from_map_position = function(position, surface_index)
    print("[MOCK] GPSUtils.gps_from_map_position called with:", position and position.x, position and position.y, surface_index)
    if not position or not surface_index then return nil end
    local x = position.x or 0
    local y = position.y or 0
    local surface = surface_index == 1 and "nauvis" or tostring(surface_index)
    return string.format("gps:%s.%s.%s", x, y, surface)
  end,
  map_position_from_gps = function(gps)
    print("[MOCK] GPSUtils.map_position_from_gps called with:", gps)
    if not gps then return nil end
    local x, y = gps:match("gps:([%-%.%d]+)%.([%-%.%d]+)")
    if not x or not y then return nil end
    return { x = tonumber(x), y = tonumber(y) }
  end,
  coords_string_from_gps = function(gps)
    print("[MOCK] GPSUtils.coords_string_from_gps called with:", gps)
    return gps or ""
  end
}

local TagEditorEventHelpers = {
  validate_tag_editor_opening = function(player, tag)
    print("[MOCK] TagEditorEventHelpers.validate_tag_editor_opening called with:", player and player.name, tag and tag.text)
    return player and player.valid and tag and tag.valid
  end,
  find_nearby_chart_tag = function(player, position, surface, radius)
    print("[MOCK] TagEditorEventHelpers.find_nearby_chart_tag called with:", player and player.name, position, surface, radius)
    return nil
  end,
  normalize_and_replace_chart_tag = function(chart_tag, player)
    print("[MOCK] TagEditorEventHelpers.normalize_and_replace_chart_tag called with:", chart_tag and chart_tag.position and chart_tag.position.x, chart_tag and chart_tag.position and chart_tag.position.y, player and player.name)
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
  is_valid_tag_modification = function(...)
    print("[MOCK] ChartTagModificationHelpers.is_valid_tag_modification called with:", ...)
    -- Accept any number of arguments for compatibility, but only use the first two
    local event, player = ...
    return event and event.tag and event.tag.valid and player and player.valid
  end,
  extract_gps = function(...)
    print("[MOCK] ChartTagModificationHelpers.extract_gps called with:", ...)
    local event, player = ...
    if not event or not event.tag or not event.tag.position then return nil, nil end
    local new_position = event.tag.position
    local old_position = event.old_position
    local surface_index = event.tag.surface and event.tag.surface.index or 1
    local new_gps = GPSUtils.gps_from_map_position(new_position, surface_index)
    local old_gps = GPSUtils.gps_from_map_position(old_position, surface_index)
    return new_gps, old_gps
  end,
  update_tag_and_cleanup = function(...)
    print("[MOCK] ChartTagModificationHelpers.update_tag_and_cleanup called with:", ...)
    return true
  end,
  update_favorites_gps = function(...)
    print("[MOCK] ChartTagModificationHelpers.update_favorites_gps called with:", ...)
    return true
  end,
}

local ErrorHandler = {
  debug_log = function(...)
    print("[MOCK] ErrorHandler.debug_log called with:", ...)
  end
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

-- Handlers must be required AFTER all mocks are set up in package.loaded!
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
    local log_spy = spy.on(ErrorHandler, "debug_log")
    mock_players[1] = {
      index = 1,
      name = "player1",
      valid = true,
      surface = mock_surfaces[1],
      gui = { screen = {} },
      play_sound = function() end,
      print = function() end
    }
    local event = {
      player_index = 1,
      tag = {
        valid = true,
        position = {x = 100.5, y = 200.5},
        surface = mock_surfaces[1]
      }
    }
    PositionUtils.needs_normalization = function(position)
      return true
    end
    TagEditorEventHelpers.normalize_and_replace_chart_tag = function(chart_tag, player)
      return { position = { x = 100, y = 200 }, valid = true, surface = chart_tag.surface, text = chart_tag.text, last_user = chart_tag.last_user, destroy = function() end }, { old = chart_tag.position, new = { x = 100, y = 200 } }
    end
    package.loaded["core.events.handlers"] = nil
    Handlers = require("core.events.handlers")
    Handlers.on_chart_tag_added(event)
    assert(#log_spy.calls > 0)
    log_spy.revert()
  end)

  it("should not normalize chart tag with integer positions", function()
    -- Patch needs_normalization to ensure normalization is NOT needed
    PositionUtils.needs_normalization = function(position)
      print("[TEST PATCH] needs_normalization forced FALSE for:", position and position.x, position and position.y)
      return false
    end
    local norm_spy = spy.on(TagEditorEventHelpers, "normalize_and_replace_chart_tag")
    local event = {
      player_index = 1,
      tag = {
        valid = true,
        position = {x = 100, y = 200}, -- Integer position
        surface = mock_surfaces[1]
      }
    }
    -- Re-require the handler to ensure it uses the patched mocks
    package.loaded["core.events.handlers"] = nil
    Handlers = require("core.events.handlers")
    Handlers.on_chart_tag_added(event)
    assert(#norm_spy.calls == 0)
    norm_spy.revert()
  end)

  it("should handle chart tag modification correctly with normalization", function()
    -- Patch needs_normalization to ensure normalization is needed
    PositionUtils.needs_normalization = function(position)
      print("[TEST PATCH] needs_normalization forced TRUE for:", position and position.x, position and position.y)
      return true
    end
    mock_players[1] = {
      index = 1,
      name = "player1",
      valid = true,
      surface = mock_surfaces[1],
      gui = { screen = {} },
      play_sound = function() end,
      print = function() end
    }
    local event = {
      player_index = 1,
      tag = {
        valid = true,
        position = {x = 100.5, y = 200.5},
        surface = mock_surfaces[1],
        text = "Test Tag"
      },
      old_position = {x = 90, y = 180}
    }
    ChartTagModificationHelpers.extract_gps = function(event, player)
      print("[TEST PATCH] extract_gps returns gps:100.5.200.5.1 and gps:90.180.1")
      return "gps:100.5.200.5.1", "gps:90.180.1"
    end
    TagEditorEventHelpers.normalize_and_replace_chart_tag = function(chart_tag, player)
      print("[TEST PATCH] normalize_and_replace_chart_tag called with:", chart_tag and chart_tag.position and chart_tag.position.x, chart_tag and chart_tag.position and chart_tag.position.y, player and player.name)
      return { position = { x = 100, y = 200 }, valid = true, surface = chart_tag.surface, text = chart_tag.text, last_user = chart_tag.last_user, destroy = function() end }, { old = chart_tag.position, new = { x = 100, y = 200 } }
    end
    package.loaded["core.events.handlers"] = nil
    Handlers = require("core.events.handlers")
    -- Set up spies AFTER requiring the handler so the handler uses the spied functions
    local norm_spy = spy.on(TagEditorEventHelpers, "normalize_and_replace_chart_tag")
    local update_tag_spy = spy.on(ChartTagModificationHelpers, "update_tag_and_cleanup")
    local update_fav_spy = spy.on(ChartTagModificationHelpers, "update_favorites_gps")
    Handlers.on_chart_tag_modified(event)
    print("[TEST] norm_spy.calls:", #norm_spy.calls)
    print("[TEST] update_tag_spy.calls:", #update_tag_spy.calls)
    print("[TEST] update_fav_spy.calls:", #update_fav_spy.calls)
    assert(#norm_spy.calls > 0)
    assert(#update_tag_spy.calls > 0)
    assert(#update_fav_spy.calls > 0)
    norm_spy.revert()
    update_tag_spy.revert()
    update_fav_spy.revert()
  end)

  it("should handle chart tag modification correctly without normalization", function()
    local norm_spy = spy.on(TagEditorEventHelpers, "normalize_and_replace_chart_tag")
    local update_tag_spy = spy.on(ChartTagModificationHelpers, "update_tag_and_cleanup")
    local update_fav_spy = spy.on(ChartTagModificationHelpers, "update_favorites_gps")
    -- Ensure player is valid and present in global game.players
    mock_players[1] = {
      index = 1,
      name = "player1",
      valid = true,
      surface = mock_surfaces[1],
      gui = { screen = {} },
      play_sound = function() end,
      print = function() end
    }
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
    -- Patch needs_normalization to ensure normalization is NOT needed
    PositionUtils.needs_normalization = function(position)
      print("[TEST PATCH] needs_normalization forced FALSE for:", position and position.x, position and position.y)
      return false
    end
    -- Patch ChartTagModificationHelpers.extract_gps to ensure different old/new gps
    ChartTagModificationHelpers.extract_gps = function(event, player)
      print("[TEST PATCH] extract_gps returns gps:100.200.1 and gps:90.180.1")
      return "gps:100.200.1", "gps:90.180.1"
    end
    -- Re-require the handler to ensure it uses the patched mocks
    package.loaded["core.events.handlers"] = nil
    Handlers = require("core.events.handlers")
    local player = game.get_player(event.player_index)
    print("[TEST] player valid:", player and player.valid)
    print("[TEST] event.tag.valid:", event.tag and event.tag.valid)
    print("[TEST] needs_normalization:", PositionUtils.needs_normalization(event.tag.position))
    print("[TEST] old_position:", event.old_position and event.old_position.x, event.old_position and event.old_position.y)
    local old_gps, new_gps = ChartTagModificationHelpers.extract_gps(event, player)
    print("[TEST] extract_gps:", old_gps, new_gps)
    print("[TEST] TagEditorEventHelpers.normalize_and_replace_chart_tag ref:", tostring(TagEditorEventHelpers.normalize_and_replace_chart_tag))
    print("[TEST] Handlers' TagEditorEventHelpers ref:", tostring(require('core.events.tag_editor_event_helpers').normalize_and_replace_chart_tag))
    print("[TEST] ChartTagModificationHelpers.update_tag_and_cleanup ref:", tostring(ChartTagModificationHelpers.update_tag_and_cleanup))
    print("[TEST] Handlers' ChartTagModificationHelpers ref:", tostring(require('core.events.chart_tag_modification_helpers').update_tag_and_cleanup))
    Handlers.on_chart_tag_modified(event)
    print("[TEST] norm_spy.calls:", #norm_spy.calls)
    print("[TEST] update_tag_spy.calls:", #update_tag_spy.calls)
    print("[TEST] update_fav_spy.calls:", #update_fav_spy.calls)
    assert(#norm_spy.calls == 0)
    assert(#update_tag_spy.calls > 0)
    assert(#update_fav_spy.calls > 0)
    norm_spy.revert()
    update_tag_spy.revert()
    update_fav_spy.revert()
  end)

  it("should update tag_editor data when chart tag is modified", function()
    local set_data_spy = spy.on(Cache, "set_tag_editor_data")
    -- Ensure player is valid and present in global game.players
    mock_players[1] = {
      index = 1,
      name = "player1",
      valid = true,
      surface = mock_surfaces[1],
      gui = { screen = {} },
      play_sound = function() end,
      print = function() end
    }
    -- Ensure old_gps and new_gps are different so the handler logic will update the tag editor
    local event = {
      player_index = 1,
      tag = {
        valid = true,
        position = {x = 101, y = 201}, -- new_gps
        surface = mock_surfaces[1],
        text = "Test Tag"
      },
      old_position = {x = 90, y = 180} -- old_gps
    }
    PositionUtils.needs_normalization = function(position)
      return false
    end
    -- Patch ChartTagModificationHelpers.extract_gps to ensure old_gps matches tag_editor_data.gps
    ChartTagModificationHelpers.extract_gps = function(event, player)
      return "gps:101.201.1", "gps:90.180.1"
    end
    -- Patch Cache.get_tag_editor_data to return a tag editor data with gps matching old_gps
    Cache.get_tag_editor_data = function()
      return { gps = "gps:90.180.1", tag = { gps = "gps:90.180.1" } }
    end
    local player = game.get_player(event.player_index)
    print("[TEST] player valid:", player and player.valid)
    print("[TEST] event.tag.valid:", event.tag and event.tag.valid)
    print("[TEST] needs_normalization:", PositionUtils.needs_normalization(event.tag.position))
    print("[TEST] old_position:", event.old_position and event.old_position.x, event.old_position and event.old_position.y)
    local old_gps, new_gps = ChartTagModificationHelpers.extract_gps(event, player)
    print("[TEST] extract_gps:", old_gps, new_gps)
    local tag_editor_data = Cache.get_tag_editor_data()
    print("[TEST] tag_editor_data.gps:", tag_editor_data and tag_editor_data.gps)
    print("[TEST] Cache.set_tag_editor_data ref:", tostring(Cache.set_tag_editor_data))
    print("[TEST] Handlers' Cache ref:", tostring(require('core.cache.cache').set_tag_editor_data))
    Handlers.on_chart_tag_modified(event)
    print("[TEST] set_data_spy.calls:", #set_data_spy.calls)
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
