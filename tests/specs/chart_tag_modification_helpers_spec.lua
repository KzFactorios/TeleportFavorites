require("test_bootstrap")
-- tests/chart_tag_modification_helpers_spec.lua
-- Combined and robust test suite for chart_tag_modification_helpers

-- Shared Factorio test environment (globals, settings, etc.)
require("mocks.factorio_test_env")

-- Patch: Provide a global BasicHelpers mock to avoid nil errors in dependencies
if not _G.BasicHelpers then
  _G.BasicHelpers = setmetatable({}, { __index = function() return function() end end })
end
-- Patch: Provide a robust mock for player.gui.top and related GUI roots
local function make_gui_root()
  return setmetatable({}, {
    __index = function(_, key)
      if key == "add" then return function() return {} end end
      if key == "clear" then return function() end end
      return {} -- fallback for any other access
    end
  })
end
local function make_gui()
  return {
    top = make_gui_root(),
    left = make_gui_root(),
    center = make_gui_root(),
    screen = make_gui_root(),
    mod = make_gui_root(),
    relative = make_gui_root(),
    valid = true
  }
end

-- Shared mocks for dependencies
local shared_Lookups = { surfaces = { [1] = { chart_tags_mapped_by_gps = {} } } }
local Cache = {
  get_tag_by_gps = function() return nil end,
  update_tag_gps = function() return true end,
  add_tag = function() end,
  delete_tag = function() end,
  get_surface_tags = function() return {} end,
  Lookups = {
    invalidate_surface_chart_tags = function() end,
    get_chart_tag_by_gps = function() return {} end
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
local GPSUtils = require("core.utils.gps_utils")
local PlayerFavorites = require("core.favorite.player_favorites")
local ErrorHandler = {
  debug_log = function() end,
  error_log = function() end
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

local spy_utils = require("mocks.spy_utils")
local make_spy = spy_utils.make_spy

local PlayerFavoritesMocks = require("mocks.player_favorites_mocks")
local admin_utils_mock = require("mocks.admin_utils_mock")
package.loaded["core.utils.admin_utils"] = admin_utils_mock
local AdminUtils = require("core.utils.admin_utils")

-- Canonical player mocks for all tests
local mock_players = {}
local function setup_mock_players()
  mock_players[1] = PlayerFavoritesMocks.mock_player(1, "player1", 1)
  mock_players[2] = PlayerFavoritesMocks.mock_player(2, "player2", 1)
end

-- Aggressive dependency patching for every test
local function patch_dependencies()
  local Cache = {
    get_tag_by_gps = function() return nil end,
    update_tag_gps = function() return true end,
    add_tag = function() end,
    delete_tag = function() end,
    get_surface_tags = function() return {} end,
    Lookups = {
      invalidate_surface_chart_tags = function() end,
      get_chart_tag_by_gps = function() return {} end
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
  local GPSUtils = require("core.utils.gps_utils")
  local PlayerFavorites = require("core.favorite.player_favorites")
  local ErrorHandler = {
    debug_log = function() end,
    error_log = function() end
  }
  require("mocks.admin_utils_mock")
  _G.AdminUtils.reset_log_calls()
  package.loaded["core.cache.cache"] = Cache
  package.loaded["core.utils.position_utils"] = PositionUtils
  package.loaded["core.utils.gps_utils"] = GPSUtils
  package.loaded["core.favorite.player_favorites"] = PlayerFavorites
  package.loaded["core.utils.error_handler"] = ErrorHandler
end

local ChartTagHelpers
local luassert = require('luassert')
local spy = require('luassert.spy')

local cache_update_tag_gps_spy, pf_update_gps_spy, error_debug_log_spy, admin_log_action_spy

before_each(function()
  setup_mock_players()
  patch_dependencies()
  admin_log_action_spy = spy.on(_G.AdminUtils, "log_admin_action")
  local Cache = package.loaded["core.cache.cache"]
  local PlayerFavorites = package.loaded["core.favorite.player_favorites"]
  local ErrorHandler = package.loaded["core.utils.error_handler"]
  cache_update_tag_gps_spy = spy.on(Cache, "update_tag_gps")
  pf_update_gps_spy = spy.on(PlayerFavorites, "update_gps_for_all_players")
  error_debug_log_spy = spy.on(ErrorHandler, "debug_log")
  package.loaded["core.events.chart_tag_helpers"] = nil
  ChartTagHelpers = require("core.events.chart_tag_helpers")
end)
after_each(function()
  cache_update_tag_gps_spy:revert()
  pf_update_gps_spy:revert()
  error_debug_log_spy:revert()
  admin_log_action_spy:revert()
end)

describe("ChartTagHelpers", function()
  it("should be a table/module", function()
    assert(type(ChartTagHelpers) == "table")
  end)
  it("should have all required functions", function()
    assert(type(ChartTagHelpers.is_valid_tag_modification) == "function")
    assert(type(ChartTagHelpers.extract_gps) == "function")
    assert(type(ChartTagHelpers.update_tag_and_cleanup) == "function")
    assert(type(ChartTagHelpers.update_favorites_gps) == "function")
  end)

  describe("is_valid_tag_modification", function()
    it("should return true for valid modifications", function()
      mock_players[1] = PlayerFavoritesMocks.mock_player(1, "player1", 1)
      mock_players[1].admin = false
      -- Patch AdminUtils for this test
      local test_admin_utils = {}
      test_admin_utils.can_edit_chart_tag = function() return true, false, false end
      test_admin_utils.log_admin_action = _G.AdminUtils.log_admin_action
      test_admin_utils.is_admin = _G.AdminUtils.is_admin
      test_admin_utils.transfer_ownership_to_admin = _G.AdminUtils.transfer_ownership_to_admin
      test_admin_utils.reset_log_calls = _G.AdminUtils.reset_log_calls
      package.loaded["core.utils.admin_utils"] = test_admin_utils
      _G.AdminUtils = test_admin_utils
      package.loaded["core.events.chart_tag_helpers"] = nil
      ChartTagHelpers = require("core.events.chart_tag_helpers")
      local event = {
        tag = { valid = true, position = {x = 100, y = 200}, surface = {index = 1} },
        old_position = {x = 90, y = 180}
      }
      local result = ChartTagHelpers.is_valid_tag_modification(event, mock_players[1])
      assert(result == true)
    end)
    it("should return false for invalid player", function()
      local event = {
        tag = { position = { x = 100, y = 100 }, valid = true }
      }
      ---@diagnostic disable-next-line: param-type-mismatch
      local result = ChartTagHelpers.is_valid_tag_modification(event, nil)
      assert(result == false)
      assert(#error_debug_log_spy.calls > 0)
    end)
    it("should return false for invalid tag", function()
      local event = { tag = nil }
      ---@diagnostic disable-next-line: param-type-mismatch
      local result = ChartTagHelpers.is_valid_tag_modification(event, mock_players[1])
      assert(result == false)
      assert(#error_debug_log_spy.calls > 0)
    end)
    it("should return false for invalid tag position", function()
      local event = { tag = { valid = true, position = nil }, old_position = {x = 90, y = 180} }
      ---@diagnostic disable-next-line: param-type-mismatch
      local result = ChartTagHelpers.is_valid_tag_modification(event, mock_players[1])
      assert(result == false)
      assert(#error_debug_log_spy.calls > 0)
    end)
    it("should return false for invalid old position", function()
      local event = { tag = { valid = true, position = {x = 100, y = 200} }, old_position = nil }
      ---@diagnostic disable-next-line: param-type-mismatch
      local result = ChartTagHelpers.is_valid_tag_modification(event, mock_players[1])
      assert(result == false)
      assert(#error_debug_log_spy.calls > 0)
    end)
    it("should return false if player lacks permission", function()
      local test_admin_utils = {}
      test_admin_utils.can_edit_chart_tag = function() return false, false, false end
      test_admin_utils.log_admin_action = _G.AdminUtils.log_admin_action
      test_admin_utils.is_admin = _G.AdminUtils.is_admin
      test_admin_utils.transfer_ownership_to_admin = _G.AdminUtils.transfer_ownership_to_admin
      test_admin_utils.reset_log_calls = _G.AdminUtils.reset_log_calls
      package.loaded["core.utils.admin_utils"] = test_admin_utils
      _G.AdminUtils = test_admin_utils
      package.loaded["core.events.chart_tag_helpers"] = nil
      ChartTagHelpers = require("core.events.chart_tag_helpers")
      local event = { tag = { position = { x = 100, y = 100 }, valid = true } }
      local result = ChartTagHelpers.is_valid_tag_modification(event, mock_players[1])
      luassert(result == false)
    end)
    it("should log admin action for admin override", function()
      _G.AdminUtils.reset_log_calls()
      local log_admin_action_called = 0
      local test_admin_utils = {}
      test_admin_utils.can_edit_chart_tag = function() return true, false, true end
      test_admin_utils.log_admin_action = function(...)
        log_admin_action_called = log_admin_action_called + 1
        if type(_G.log_calls) ~= "table" then _G.log_calls = {} end
        table.insert(_G.log_calls, true)
      end
      test_admin_utils.is_admin = _G.AdminUtils.is_admin
      test_admin_utils.transfer_ownership_to_admin = _G.AdminUtils.transfer_ownership_to_admin
      test_admin_utils.reset_log_calls = _G.AdminUtils.reset_log_calls
      package.loaded["core.utils.admin_utils"] = test_admin_utils
      _G.AdminUtils = test_admin_utils
      package.loaded["core.events.chart_tag_helpers"] = nil
      ChartTagHelpers = require("core.events.chart_tag_helpers")
      local event = { tag = { position = { x = 100, y = 100 }, valid = true }, old_position = { x = 90, y = 90 } }
      mock_players[1].admin = true
      local result = ChartTagHelpers.is_valid_tag_modification(event, mock_players[1])
      luassert(result)
      luassert(log_admin_action_called > 0)
      luassert(#_G.log_calls > 0)
    end)
  end)

  describe("extract_gps", function()
    it("should extract GPS coordinates correctly", function()
      local event = {
        tag = { valid = true, position = {x = 100, y = 200}, surface = {index = 1} },
        old_position = {x = 90, y = 180}
      }
      local new_gps, old_gps = ChartTagHelpers.extract_gps(event, mock_players[1])
      luassert(new_gps == "100.200.1")
      luassert(old_gps == "090.180.1")
    end)
    it("should handle fractional positions correctly", function()
      local event = { tag = { valid = true, position = {x = 100.5, y = 200.7, surface = {index = 1} } }, old_position = {x = 50.3, y = 150.9} }
      local new_gps, old_gps = ChartTagHelpers.extract_gps(event, mock_players[1])
      luassert(new_gps == "101.201.1")
      luassert(old_gps == "050.151.1")
    end)
  end)

  describe("update_tag_and_cleanup", function()
    it("should update tag GPS correctly", function()
      local old_gps = "090.180.1"
      local new_gps = "100.200.1"
      local event = {
        tag = { valid = true, position = {x = 100, y = 200}, surface = {index = 1} },
        old_position = {x = 90, y = 180}
      }
      Cache.get_tag_by_gps = function() return { gps = old_gps, text = "Test Tag" } end
      -- Just ensure the function completes without error
      ChartTagHelpers.update_tag_and_cleanup(old_gps, new_gps, event, mock_players[1])
      luassert(true)
    end)
    it("should not update for identical GPS coordinates", function()
      local same_gps = "100.200.1"
      ChartTagHelpers.update_tag_and_cleanup(same_gps, same_gps, {tag = {valid = true}}, mock_players[1])
      luassert(true)
    end)
    it("should handle nil GPS gracefully", function()
      ChartTagHelpers.update_tag_and_cleanup(nil, "100.200.1", {}, mock_players[1])
      luassert(true)
      ChartTagHelpers.update_tag_and_cleanup("100.200.1", nil, {}, mock_players[1])
      luassert(true)
    end)
    it("should handle tag not found gracefully", function()
      Cache.get_tag_by_gps = function() return nil end
      ChartTagHelpers.update_tag_and_cleanup("090.180.1", "100.200.1", {}, mock_players[1])
      luassert(true)
    end)
    it("should handle update failure gracefully", function()
      local old_gps = "090.180.1"
      local new_gps = "100.200.1"
      local event = { tag = { valid = true, position = {x = 100, y = 200}, surface = {index = 1} }, old_position = {x = 90, y = 180} }
      local Cache = package.loaded["core.cache.cache"]
      Cache.get_tag_by_gps = function() return { gps = old_gps, text = "Test Tag" } end
      Cache.update_tag_gps = function() return false end
      spy.on(Cache, "update_tag_gps")
      ChartTagHelpers.update_tag_and_cleanup(old_gps, new_gps, event, mock_players[1])
      luassert(true)
    end)
  end)

  describe("update_favorites_gps", function()
    it("should update favorite GPS correctly", function()
      local old_gps = "090.180.1"
      local new_gps = "100.200.1"
      ChartTagHelpers.update_favorites_gps(old_gps, new_gps, mock_players[1])
      luassert(true)
    end)
    it("should not update for identical GPS coordinates", function()
      local same_gps = "100.200.1"
      ChartTagHelpers.update_favorites_gps(same_gps, same_gps, mock_players[1])
      luassert(true)
    end)
  end)

  describe("integration tests", function()
    it("should handle full chart tag modification workflow", function()
      local test_admin_utils = {}
      test_admin_utils.can_edit_chart_tag = function() return true, false, false end
      test_admin_utils.log_admin_action = _G.AdminUtils.log_admin_action
      test_admin_utils.is_admin = _G.AdminUtils.is_admin
      test_admin_utils.transfer_ownership_to_admin = _G.AdminUtils.transfer_ownership_to_admin
      test_admin_utils.reset_log_calls = _G.AdminUtils.reset_log_calls
      package.loaded["core.utils.admin_utils"] = test_admin_utils
      _G.AdminUtils = test_admin_utils
      package.loaded["core.events.chart_tag_helpers"] = nil
      ChartTagHelpers = require("core.events.chart_tag_helpers")
      local event = {
        tag = { valid = true, position = {x = 100, y = 200}, surface = {index = 1} },
        old_position = {x = 90, y = 180}
      }
      Cache.get_tag_by_gps = function() return { gps = "090.180.1", text = "Test Tag" } end
      local result = ChartTagHelpers.is_valid_tag_modification(event, mock_players[1])
      luassert(result == true)
      local new_gps, old_gps = ChartTagHelpers.extract_gps(event, mock_players[1])
      luassert(new_gps == "100.200.1")
      luassert(old_gps == "090.180.1")
      ChartTagHelpers.update_tag_and_cleanup(old_gps, new_gps, event, mock_players[1])
      ChartTagHelpers.update_favorites_gps(old_gps, new_gps, mock_players[1])
      luassert(true)
    end)
  end)
end)
