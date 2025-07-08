local bootstrap = require("tests.test_bootstrap")
local Cache = bootstrap.Cache
local make_spy = bootstrap.make_spy
-- tests/handlers_tag_editor_open_spec.lua
-- Focused tests for the on_open_tag_editor_custom_input handler function

-- Patch for Busted globals (describe, it, before_each, etc.)
if not describe then
  describe = function(name, fn) fn() end
end
if not it then
  it = function(name, fn) fn() end
end
if not before_each then
  before_each = function(fn) fn() end
end
if not after_each then
  after_each = function(fn) fn() end
end

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

local PositionUtils = {
  needs_normalization = function(position) 
    if not position then return false end
    return position.x ~= math.floor(position.x) or position.y ~= math.floor(position.y)
  end
}

local GPSUtils = {
  gps_from_map_position = function(position, surface_index) 
    if not position then return nil end
    if type(surface_index) ~= "number" then
      surface_index = 1
    end
    return "gps:" .. position.x .. "." .. position.y .. "." .. surface_index
  end
}

local TagEditorEventHelpers = {
  validate_tag_editor_opening = function() 
    return true
  end,
  find_nearby_chart_tag = function() 
    return nil 
  end
}

local PlayerFavorites = {
  new = function() 
    return {
      get_favorite_by_gps = function() 
        return nil
      end
    }
  end
}

local CursorUtils = {
  end_drag_favorite = function() end
}

local Settings = {
  get_chart_tag_click_radius = function() return 5 end
}

local tag_editor = {
  build = function() end
}

-- Mock package.loaded for dependencies
package.loaded["core.cache.cache"] = Cache
package.loaded["core.utils.position_utils"] = PositionUtils
package.loaded["core.utils.gps_utils"] = GPSUtils
package.loaded["core.events.tag_editor_event_helpers"] = TagEditorEventHelpers
package.loaded["core.utils.cursor_utils"] = CursorUtils
package.loaded["core.utils.settings_access"] = Settings
package.loaded["core.favorite.player_favorites"] = PlayerFavorites
package.loaded["gui.tag_editor.tag_editor"] = tag_editor
package.loaded["core.utils.error_handler"] = { debug_log = function() end }
package.loaded["gui.favorites_bar.fave_bar"] = {build = function() end}
package.loaded["core.utils.gui_helpers"] = {}
package.loaded["core.utils.gui_validation"] = {find_child_by_name = function() return nil end}
package.loaded["prototypes.enums.enum"] = {GuiEnum = {GUI_FRAME = {}}}
package.loaded["core.events.chart_tag_modification_helpers"] = {
  is_valid_tag_modification = function() return true end,
  extract_gps = function() return "gps:100.200.1", "gps:50.150.1" end,
  update_tag_and_cleanup = function() end,
  update_favorites_gps = function() end,
}
package.loaded["core.control.fave_bar_gui_labels_manager"] = {
  register_all = function() end,
  initialize_all_players = function() end,
  update_label_for_player = function() end
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

_G.game = {
  players = mock_players,
  get_player = function(player_index)
    return mock_players[player_index]
  end,
  surfaces = mock_surfaces
}

-- Import the module under test
local Handlers = require("core.events.handlers")

describe("Handlers.on_open_tag_editor_custom_input", function()
  local mock_player
  local mock_event
  
  before_each(function()
    -- Always reset methods to default implementations before each test
    TagEditorEventHelpers.validate_tag_editor_opening = function() return true, nil end
    TagEditorEventHelpers.find_nearby_chart_tag = function() return nil end
    tag_editor.build = function() end
    Cache.get_player_data = function() return { tag_editor_data = nil } end
    Cache.create_tag_editor_data = function() return {} end
    Cache.set_tag_editor_data = function() end
    Cache.get_tag_by_gps = function() return nil end
    GPSUtils.gps_from_map_position = function() return "gps:100.200.1" end
    CursorUtils.end_drag_favorite = function() end

    -- Create mock player
    mock_player = {
      index = 1,
      name = "test_player",
      valid = true,
      surface = mock_surfaces[1],
      _cached_tag_editor_data = nil,
      play_sound = function() end
    }
    mock_players[1] = mock_player
    mock_event = {
      player_index = 1,
      cursor_position = {
        x = 100,
        y = 200
      }
    }
  end)
  
  it("should not process for invalid players", function()
    mock_event.player_index = 999 -- Invalid player index
    local validate_calls = 0
    TagEditorEventHelpers.validate_tag_editor_opening = function() validate_calls = validate_calls + 1; return true end
    Handlers.on_open_tag_editor_custom_input(mock_event)
    assert(validate_calls == 0, "validate_tag_editor_opening should not be called for invalid player")
  end)
  
  it("should validate tag editor opening", function()
    local validate_calls = {}
    TagEditorEventHelpers.validate_tag_editor_opening = function() 
      table.insert(validate_calls, {})
      return true
    end
    package.loaded["core.events.handlers"] = nil
    local Handlers = require("core.events.handlers")
    Handlers.on_open_tag_editor_custom_input(mock_event)
    assert(#validate_calls > 0, "validate_tag_editor_opening should be called")
  end)
  
  it("should not proceed if validation fails", function()
    -- Setup: Validation fails
    local build_calls = 0
    tag_editor.build = function() build_calls = build_calls + 1 end
    TagEditorEventHelpers.validate_tag_editor_opening = function() return false, "Some reason" end
    Handlers.on_open_tag_editor_custom_input(mock_event)
    assert(build_calls == 0, "tag_editor.build should not be called if validation fails")
  end)
  
  it("should end drag favorite if validation fails with 'Drag mode active'", function()
    -- Setup: Validation fails with drag mode active
    local drag_calls = {}
    CursorUtils.end_drag_favorite = function() 
      table.insert(drag_calls, {})
    end
    TagEditorEventHelpers.validate_tag_editor_opening = function() return false, "Drag mode active" end
    package.loaded["core.events.handlers"] = nil
    local Handlers = require("core.events.handlers")
    Handlers.on_open_tag_editor_custom_input(mock_event)
    assert(#drag_calls > 0, "end_drag_favorite should be called if validation fails with 'Drag mode active'")
  end)
  
  it("should check for nearby chart tag if cursor position is provided", function()
    local find_calls = {}
    TagEditorEventHelpers.find_nearby_chart_tag = function() 
      table.insert(find_calls, {})
    end
    package.loaded["core.events.handlers"] = nil
    local Handlers = require("core.events.handlers")
    Handlers.on_open_tag_editor_custom_input(mock_event)
    assert(#find_calls > 0, "find_nearby_chart_tag should be called when cursor position is provided")
  end)
  
  it("should not check for nearby chart tag if cursor position is missing", function()
    -- Setup: No cursor position
    mock_event.cursor_position = nil

    -- Patch: use a local call-tracking variable for find_nearby_chart_tag
    local call_count = 0
    TagEditorEventHelpers.find_nearby_chart_tag = function() call_count = call_count + 1 end

    Handlers.on_open_tag_editor_custom_input(mock_event)

    assert(call_count == 0, "find_nearby_chart_tag should not be called when cursor position is missing")
  end)
  it("should populate tag data with cursor position if no chart tag found", function()
    -- Setup: No chart tag found
    local set_tag_editor_data_calls = {}
    Cache.set_tag_editor_data = function(a, b)
      table.insert(set_tag_editor_data_calls, {a, b})
    end
    local build_calls = {}
    tag_editor.build = function(a)
      table.insert(build_calls, {a})
    end
    -- Create a new mock_event and mock_player for this test
    local mock_player = {
      index = 1,
      name = "test_player",
      valid = true,
      surface = { index = 1, name = "nauvis", valid = true },
      _cached_tag_editor_data = nil,
      play_sound = function() end
    }
    local mock_event = {
      player_index = 1,
      cursor_position = { x = 100, y = 200 }
    }
    _G.game.players[1] = mock_player
    package.loaded["core.events.handlers"] = nil
    local Handlers = require("core.events.handlers")
    Handlers.on_open_tag_editor_custom_input(mock_event)
    assert(#set_tag_editor_data_calls > 0, "set_tag_editor_data should be called")
    assert(#build_calls > 0, "tag_editor.build should be called")
    -- The tag editor data should contain GPS from cursor position
    local has_correct_gps = false
    for _, call_args in ipairs(set_tag_editor_data_calls) do
      local data = call_args[2]
      if data.gps == "gps:100.200.1" then
        has_correct_gps = true
        break
      end
    end
    assert(has_correct_gps, "Tag editor data should contain GPS from cursor position")
  end)
  it("should populate tag data with chart tag if found", function()
    -- Setup: Chart tag found
    local mock_chart_tag = {
      position = {x = 100, y = 200},
      valid = true,
      surface = mock_surfaces[1],
      text = "Test Tag",
      last_user = mock_player,
      icon = "some-icon"
    }
    local set_tag_editor_data_calls = {}
    Cache.set_tag_editor_data = function(a, b)
      table.insert(set_tag_editor_data_calls, {a, b})
    end
    local build_calls = {}
    tag_editor.build = function(a)
      table.insert(build_calls, {a})
    end
    -- Create a new mock_event and mock_player for this test
    local mock_player = {
      index = 1,
      name = "test_player",
      valid = true,
      surface = { index = 1, name = "nauvis", valid = true },
      _cached_tag_editor_data = nil,
      play_sound = function() end
    }
    local mock_event = {
      player_index = 1,
      cursor_position = { x = 100, y = 200 }
    }
    _G.game.players[1] = mock_player
    TagEditorEventHelpers.find_nearby_chart_tag = function() return mock_chart_tag end
    GPSUtils.gps_from_map_position = function() return "gps:100.200.1" end
    package.loaded["core.events.handlers"] = nil
    local Handlers = require("core.events.handlers")
    Handlers.on_open_tag_editor_custom_input(mock_event)
    assert(#set_tag_editor_data_calls > 0, "set_tag_editor_data should be called")
    assert(#build_calls > 0, "tag_editor.build should be called")
    -- The tag editor data should contain information from the chart tag
    local has_correct_chart_tag = false
    for _, call_args in ipairs(set_tag_editor_data_calls) do
      local data = call_args[2]
      if data.chart_tag == mock_chart_tag and
         data.gps == "gps:100.200.1" and
         data.text == "Test Tag" and
         data.icon == "some-icon" then
        has_correct_chart_tag = true
        break
      end
    end
    assert(has_correct_chart_tag, "Tag editor data should contain information from the chart tag")
  end)
  end)
  
  it("should check if the tag is a favorite when chart tag is found", function()
    -- Setup: Chart tag found
    local mock_player = {
      index = 1,
      name = "test_player",
      valid = true,
      surface = { index = 1, name = "nauvis", valid = true },
      _cached_tag_editor_data = nil,
      play_sound = function() end
    }
    local mock_chart_tag = {
      position = {x = 100, y = 200},
      valid = true,
      surface = mock_surfaces[1],
      text = "Test Tag",
      last_user = mock_player
    }
    TagEditorEventHelpers.find_nearby_chart_tag = function() return mock_chart_tag end
    -- Setup: Tag is a favorite
    local mock_favorite_entry = {
      gps = "gps:100.200.1",
      text = "Test Tag",
      icon = "some-icon"
    }
    local mock_player_favorites = {
      get_favorite_by_gps = function() 
        return mock_favorite_entry, 1
      end
    }
    PlayerFavorites.new = function() 
      return mock_player_favorites
    end
    local set_tag_editor_data_calls = {}
    Cache.set_tag_editor_data = function(...)
      table.insert(set_tag_editor_data_calls, {...})
    end
    -- Create a new mock_event for this test
    local mock_event = {
      player_index = 1,
      cursor_position = { x = 100, y = 200 }
    }
    _G.game.players[1] = mock_player
    package.loaded["core.events.handlers"] = nil
    local Handlers = require("core.events.handlers")
    Handlers.on_open_tag_editor_custom_input(mock_event)
    -- The tag editor data should indicate this is a favorite
    assert(#set_tag_editor_data_calls > 0, "Tag editor data should indicate this is a favorite")
  end)
  it("should use existing tag_editor_data gps if present", function()
    -- Setup: No chart tag found
    TagEditorEventHelpers.find_nearby_chart_tag = function() return nil end
    -- Setup: No cursor position and new mock_event
    local mock_event = {
      player_index = 1,
      cursor_position = nil
    }
    -- Setup: Existing tag editor data with gps
    local existing_tag_data = {
      tag = {
        gps = "gps:300.400.1"
      },
      gps = "gps:300.400.1"
    }
    Cache.get_player_data = function() 
      return { tag_editor_data = existing_tag_data } 
    end
    local set_tag_editor_data_calls = {}
    local orig_set_tag_editor_data = Cache.set_tag_editor_data
    Cache.set_tag_editor_data = function(player, data)
      table.insert(set_tag_editor_data_calls, {player, data})
    end
    package.loaded["core.events.handlers"] = nil
    local Handlers = require("core.events.handlers")
    Handlers.on_open_tag_editor_custom_input(mock_event)
    -- The tag editor data should contain the existing GPS
    local has_existing_gps = false
    for _, call_args in ipairs(set_tag_editor_data_calls) do
      local data = call_args[2]
      if data and data.gps == "gps:300.400.1" then
        has_existing_gps = true
        break
      end
    end
    assert(has_existing_gps, "Tag editor data should contain the existing GPS")
    -- Restore original mock
    Cache.set_tag_editor_data = orig_set_tag_editor_data
  end)
  
  it("should build tag editor after setting data", function()
    local build_calls = {}
    local orig_build = tag_editor.build
    tag_editor.build = function(player)
      table.insert(build_calls, {player})
    end
    -- Create a new mock_event and mock_player for this test
    local mock_player = {
      index = 1,
      name = "test_player",
      valid = true,
      surface = { index = 1, name = "nauvis", valid = true },
      _cached_tag_editor_data = nil,
      play_sound = function() end
    }
    local mock_event = {
      player_index = 1,
      cursor_position = { x = 100, y = 200 }
    }
    -- Patch game.players for this test
    _G.game.players[1] = mock_player
    package.loaded["core.events.handlers"] = nil
    local Handlers = require("core.events.handlers")
    Handlers.on_open_tag_editor_custom_input(mock_event)
    assert(#build_calls > 0, "tag_editor.build should be called")
    local called_with_player = false
    for _, call_args in ipairs(build_calls) do
      if call_args[1] == mock_player then called_with_player = true break end
    end
    assert(called_with_player, "tag_editor.build should be called with the player")
    -- Restore original mock
    tag_editor.build = orig_build
  end)
