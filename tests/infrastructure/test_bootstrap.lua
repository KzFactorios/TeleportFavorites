if not _G.storage then
  _G.storage = {
    cache = {},
    players = {},
    surfaces = {},
  }
end
-- Try to load luacov for coverage, but don't fail if it's not available
local success, luacov = pcall(require, "luacov")
if not success then
  print("LuaCov not found. Coverage will not be collected.")
end
-- Patch FavoriteUtils mock globally before any SUT loads
local favorite_utils_mock = require("mocks.favorite_utils_mock")
_G.FavoriteUtils = favorite_utils_mock
package.loaded["core.favorite.favorite_utils"] = favorite_utils_mock
-- tests/test_bootstrap.lua
-- Canonical test bootstrap for TeleportFavorites
-- Ensures all mocks and package.loaded patches are in place BEFORE any SUT or test code is loaded.

-- Patch AdminUtils mock before any other require
require("tests.mocks.admin_utils_mock")

-- Setup global Factorio environment with proper settings mock
require("tests.mocks.factorio_test_env")

-- Canonical player mocks
local PlayerFavoritesMocks = require("tests.mocks.player_favorites_mocks")

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

-- Load real Cache module and ensure it has proper dependencies
local Cache = require("core.cache.cache")
if not Cache.Lookups then
  Cache.Lookups = {
    ensure_surface_cache = function() end,
    invalidate_surface_chart_tags = function() end
  }
end

package.loaded["core.control.fave_bar_gui_labels_manager"] = FaveBarGuiLabelsManager
package.loaded["gui.favorites_bar.fave_bar"] = fave_bar
package.loaded["core.utils.position_utils"] = { 
  needs_normalization = function() return false end,
  is_walkable_position = function() return true end
}
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
-- Load real ErrorHandler module instead of mock
local ErrorHandler = require("core.utils.error_handler")
package.loaded["core.utils.error_handler"] = ErrorHandler
package.loaded["core.utils.cursor_utils"] = { end_drag_favorite = function() end }
package.loaded["gui.tag_editor.tag_editor"] = { build = function() end }
package.loaded["core.events.tag_editor_event_helpers"] = {
  validate_tag_editor_opening = function() return true end,
  find_nearby_chart_tag = function() return nil end
}
package.loaded["core.cache.settings_cache"] = { get_chart_tag_click_radius = function() return 5 end }
--[[
-- Don't patch player_favorites - let it load normally for testing
package.loaded["core.favorite.player_favorites"] = setmetatable({
  new = function(player)
    return {
      player = player or { index = 1, surface = { index = 1 } },
      player_index = (player and player.index) or 1,
      surface_index = (player and player.surface and player.surface.index) or 1,
      favorites = {},
      get_favorite_by_gps = function() return nil end,
      update_gps_coordinates = function() return true end,
      add_favorite = function() return true, nil end,
      remove_favorite = function() return true end,
      toggle_favorite_lock = function() return true end,
      get_favorite_by_slot = function() return nil end
    }
  end,
  update_gps_for_all_players = function() return {} end
}, { __index = function() return function() end end })
--]]
package.loaded["core.utils.gui_validation"] = { find_child_by_name = function() return nil end }
package.loaded["core.utils.gui_helpers"] = {}
package.loaded["core.events.chart_tag_modification_helpers"] = {
  is_valid_tag_modification = function() return true end,
  extract_gps = function() return "gps:100,200,nauvis", "gps:50,150,nauvis" end,
  update_tag_and_cleanup = function() end,
  update_favorites_gps = function() end
}
-- Let enum load normally - it has utility functions the tests need
-- local enum_mock = require("tests.mocks.enum_mock")
-- package.loaded["prototypes.enums.enum"] = enum_mock
-- 
-- -- Add CoreEnums to the enum mock for tests that expect it
-- enum_mock.CoreEnums = {
--   TELEPORT_STRATEGY = {
--     SAFE_TELEPORT = "safe_teleport",
--     FORCE_TELEPORT = "force_teleport"
--   }
-- }

-- Patch Lua package.path to include tests/ and tests/mocks/ for require()
package.path = table.concat({
  "tests/?.lua",
  "tests/mocks/?.lua",
  package.path
}, ";")

-- Optionally, patch busted output to always flush prints
io.stdout:setvbuf('no')

-- Let constants load normally - don't patch it
-- local constants_mock = require("tests.mocks.constants_mock")
-- constants_mock.settings.MAX_FAVORITE_SLOTS = 10
-- constants_mock.settings.TAG_TEXT_MAX_LENGTH = 100 -- Add missing constant
-- package.loaded["constants"] = constants_mock
-- _G.Constants = constants_mock

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
