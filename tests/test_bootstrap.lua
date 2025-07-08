-- tests/test_bootstrap.lua
-- Canonical test bootstrap for TeleportFavorites
-- Ensures all mocks and package.loaded patches are in place BEFORE any SUT or test code is loaded.

-- Patch AdminUtils mock before any other require
require("tests.mocks.admin_utils_mock")

-- Canonical player mocks
local PlayerFavoritesMocks = require("tests.mocks.player_favorites_mocks")

-- Create mocks for dependencies
local Cache = {
  init = function() end,
  reset_transient_player_states = function() end,
  get_player_data = function() return {} end,
  set_tag_editor_data = function() end,
  ensure_surface_cache = function(...)
    print("[DIAGNOSTIC] ensure_surface_cache called with:", ...)
  end,
  set_player_surface = function() end,
  get_tag_by_gps = function() return nil end,
  get_tag_editor_data = function() return {} end,
  Lookups = {
    ensure_surface_cache = function() end,
    invalidate_surface_chart_tags = function() end
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

-- Shared spy utility
local spy_utils = require("tests.mocks.spy_utils")
local make_spy = spy_utils.make_spy

-- Patch all required modules BEFORE any SUT is loaded
package.loaded["core.cache.cache"] = Cache
package.loaded["core.control.fave_bar_gui_labels_manager"] = FaveBarGuiLabelsManager
package.loaded["gui.favorites_bar.fave_bar"] = fave_bar
package.loaded["core.utils.position_utils"] = { needs_normalization = function() return false end }
-- Patch GPSUtils with all required methods for tests
local function pad(num, len)
  local s = tostring(math.floor(num + 0.5))
  while #s < (len or 3) do s = "0" .. s end
  return s
end
package.loaded["core.utils.gps_utils"] = setmetatable({
  gps_from_map_position = function(map_position, surface_index)
    if not map_position or type(map_position.x) ~= "number" or type(map_position.y) ~= "number" then
      return "000.000.1"
    end
    surface_index = surface_index or 1
    local x = math.floor(map_position.x + 0.5)
    local y = math.floor(map_position.y + 0.5)
    return pad(x, 3) .. "." .. pad(y, 3) .. "." .. tostring(surface_index)
  end,
  coords_string_from_gps = function() return "100,200" end,
  map_position_from_gps = function() return {x=100, y=200} end,
  get_surface_index_from_gps = function(gps) return 1 end
}, { __index = function() return function() end end })
package.loaded["core.utils.error_handler"] = { debug_log = function() end }
package.loaded["core.utils.cursor_utils"] = { end_drag_favorite = function() end }
package.loaded["gui.tag_editor.tag_editor"] = { build = function() end }
package.loaded["core.events.tag_editor_event_helpers"] = {
  validate_tag_editor_opening = function() return true end,
  find_nearby_chart_tag = function() return nil end
}
package.loaded["core.utils.settings_access"] = { get_chart_tag_click_radius = function() return 5 end }
package.loaded["core.favorite.player_favorites"] = setmetatable({
  new = function(player)
    return {
      player = player or { index = 1, surface = { index = 1 } },
      player_index = (player and player.index) or 1,
      surface_index = (player and player.surface and player.surface.index) or 1,
      favorites = {},
      get_favorite_by_gps = function() return nil end,
      update_gps_coordinates = function() return true end
    }
  end,
  update_gps_for_all_players = function() return {} end
}, { __index = function() return function() end end })
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

-- Patch Lua package.path to include tests/ and tests/mocks/ for require()
package.path = table.concat({
  "tests/?.lua",
  "tests/mocks/?.lua",
  package.path
}, ";")

-- Optionally, patch busted output to always flush prints
io.stdout:setvbuf('no')

-- Set up spies for all handler dependencies BEFORE SUT is loaded
make_spy(fave_bar, "build")
make_spy(FaveBarGuiLabelsManager, "register_all")
make_spy(FaveBarGuiLabelsManager, "initialize_all_players")
make_spy(FaveBarGuiLabelsManager, "update_label_for_player")
make_spy(Cache, "reset_transient_player_states")
local tag_editor = { build = function() end }
make_spy(tag_editor, "build")
package.loaded["gui.tag_editor.tag_editor"] = tag_editor
local cursor_utils = { end_drag_favorite = function() end }
make_spy(cursor_utils, "end_drag_favorite")
package.loaded["core.utils.cursor_utils"] = cursor_utils

-- Export mocks for use in test files
return {
  Cache = Cache,
  FaveBarGuiLabelsManager = FaveBarGuiLabelsManager,
  fave_bar = fave_bar,
  make_spy = make_spy,
  PlayerFavoritesMocks = PlayerFavoritesMocks
}
