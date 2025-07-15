-- tests/mocks/settings_cache_mock.lua
-- Centralized mock for core.cache.settings_cache module
-- Provides both new and legacy API methods for backward compatibility

local SettingsCacheMock = {}

-- Default mock settings that can be overridden in tests
local default_settings = {
  favorites_on = true,
  show_player_coords = true,
  show_teleport_history = true,
  chart_tag_click_radius = 5,
  favorites_bar_placement = "top",
  enable_debug_logging = false
}

--- Mock for new static method API
--- @param player table|nil Mock player object
--- @return table Settings table
function SettingsCacheMock.get_player_settings(player)
  return default_settings
end

--- Mock for boolean settings
--- @param player table|nil Mock player object 
--- @param setting_name string Setting name
--- @return boolean
function SettingsCacheMock.get_boolean_setting(player, setting_name)
  local settings = default_settings
  local value = settings[setting_name]
  if type(value) == "boolean" then
    return value
  end
  return false
end

--- Mock for number settings
--- @param player table|nil Mock player object
--- @param setting_name string Setting name
--- @return number
function SettingsCacheMock.get_number_setting(player, setting_name)
  local settings = default_settings
  local value = settings[setting_name]
  if type(value) == "number" then
    return value
  end
  return 0
end

--- Mock for radius setting (commonly used in tests)
--- @return number
function SettingsCacheMock.get_chart_tag_click_radius()
  return default_settings.chart_tag_click_radius or 5
end

--- Legacy compatibility method (instance-style call)
--- @deprecated Use SettingsCacheMock.get_player_settings instead
--- @param player table|nil Mock player object
--- @return table Settings table
function SettingsCacheMock:getPlayerSettings(player)
  return SettingsCacheMock.get_player_settings(player)
end

--- Cache management mocks
function SettingsCacheMock.clear_player_cache(player)
  -- No-op in mock
end

function SettingsCacheMock.clear_all_caches()
  -- No-op in mock
end

--- Utility function for tests to override default settings
--- @param new_settings table Settings to override
function SettingsCacheMock.set_mock_settings(new_settings)
  for key, value in pairs(new_settings) do
    default_settings[key] = value
  end
end

--- Utility function for tests to reset to defaults
function SettingsCacheMock.reset_mock_settings()
  default_settings = {
    favorites_on = true,
    show_player_coords = true,
    show_teleport_history = true,
    chart_tag_click_radius = 5,
    favorites_bar_placement = "top",
    enable_debug_logging = false
  }
end

return SettingsCacheMock
