-- tests/mocks/shared_mocks.lua
-- Centralized mock setup for commonly used modules across test files

local SharedMocks = {}

--- Sets up the standard settings cache mock for tests
--- @param overrides table|nil Optional settings to override defaults
function SharedMocks.setup_settings_cache_mock(overrides)
  local SettingsCacheMock = require("tests.mocks.settings_cache_mock")
  
  if overrides then
    SettingsCacheMock.set_mock_settings(overrides)
  else
    SettingsCacheMock.reset_mock_settings()
  end
  
  package.loaded["core.cache.settings_cache"] = SettingsCacheMock
  -- Also support legacy path for tests that haven't been updated yet
  package.loaded["core.cache.settings"] = SettingsCacheMock
  
  -- Set up Cache mock with SettingsCache attached
  local CacheMock = package.loaded["core.cache.cache"] or {}
  CacheMock.SettingsCache = SettingsCacheMock
  package.loaded["core.cache.cache"] = CacheMock
end

--- Sets up common utility mocks used across many tests
function SharedMocks.setup_common_mocks()
  -- Error handler mock
  package.loaded["core.utils.error_handler"] = {
    debug_log = function() end,
    safe_log = function() end
  }
  
  -- Safe helpers mock
  package.loaded["core.utils.safe_helpers"] = {
    is_valid_player = function(player)
      return player and player.valid == true
    end,
    is_valid_element = function(element)
      return element and element.valid == true
    end
  }
  
  -- Basic helpers mock (formerly small_helpers)
  package.loaded["core.utils.basic_helpers"] = {
    should_hide_favorites_bar_for_space_platform = function() return false end,
    is_valid_player = function(player) return player and player.valid end,
    is_valid_element = function(element) return element and element.valid end,
    is_blank_favorite = function(fav) return not fav or fav.gps == "" end,
    is_locked_favorite = function(fav) return fav and fav.locked == true end
  }
end

--- Sets up global Factorio defines mock
function SharedMocks.setup_defines_mock()
  _G.defines = {
    controllers = {
      god = "god",
      spectator = "spectator", 
      character = "character"
    },
    events = {
      on_gui_click = 1,
      on_gui_closed = 2,
      on_chart_tag_added = 3,
      on_chart_tag_removed = 4
    }
  }
end

--- Comprehensive setup for most test files
--- @param settings_overrides table|nil Optional settings to override
function SharedMocks.setup_standard_test_env(settings_overrides)
  SharedMocks.setup_common_mocks()
  SharedMocks.setup_settings_cache_mock(settings_overrides)
  SharedMocks.setup_defines_mock()
end

return SharedMocks
