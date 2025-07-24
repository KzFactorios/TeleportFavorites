---@diagnostic disable: undefined-global


local Constants = require("constants")
local BasicHelpers = require("core.utils.basic_helpers")

local Settings = {}

local DEFAULT_SETTINGS = {
  favorites_on = true,
  enable_teleport_history = true,
}

local player_settings_cache = {}

local CACHE_INVALIDATION_INTERVAL = 3600

local function get_player_mod_settings(player)
  if not BasicHelpers.is_valid_player(player) then
    return nil
  end
  return player.mod_settings
end

local function get_global_settings(player)
  if not BasicHelpers.is_valid_player(player) then
    return nil
  end
  return settings.get_player_settings(player)
end

local function is_cache_valid(player_index)
  local cached = player_settings_cache[player_index]
  if not cached then
    return false
  end

  local current_tick = game and game.tick or 0
  return (current_tick - cached.last_updated) < CACHE_INVALIDATION_INTERVAL
end

local function build_fresh_settings(player)
  local settings_table = {}
  local mod_settings = get_player_mod_settings(player)

  for setting_name, default_value in pairs(DEFAULT_SETTINGS) do
    if type(default_value) == "boolean" then
      if mod_settings then
        local setting = mod_settings[setting_name]
        if setting and setting.value ~= nil and type(setting.value) == "boolean" then
          settings_table[setting_name] = setting.value
        else
          settings_table[setting_name] = default_value
        end
      else
        settings_table[setting_name] = default_value
      end
    end
  end

  return settings_table
end

function Settings.get_number_setting(player, setting_name, default, min_value, max_value)
  local global_settings = get_global_settings(player)
  if not global_settings then
    return default
  end

  local setting = global_settings[setting_name]
  if setting and setting.value ~= nil then
    local value = tonumber(setting.value)
    if value then
      if min_value and value < min_value then
        return min_value
      end
      if max_value and value > max_value then
        return max_value
      end
      return value
    end
  end

  return default
end

function Settings.get_player_settings(player)
  if not BasicHelpers.is_valid_player(player) then
    return build_fresh_settings(nil)
  end

  local player_index = (player and player.index) or nil

  if player_index and is_cache_valid(player_index) then
    return player_settings_cache[player_index].settings
  end

  local fresh_settings = build_fresh_settings(player)
  if player_index then
    player_settings_cache[player_index] = {
      settings = fresh_settings,
      last_updated = game and game.tick or 0
    }
  end

  return fresh_settings
end

function Settings.get_chart_tag_click_radius(player)
  local default = 10
  if Constants and Constants.settings and Constants.settings.CHART_TAG_CLICK_RADIUS then
    default = math.floor(tonumber(Constants.settings.CHART_TAG_CLICK_RADIUS) or 10)
  end
  return Settings.get_number_setting(player, "chart-tag-click-radius", default, 1, 50)
end

function Settings.invalidate_player_cache(player)
  if not BasicHelpers.is_valid_player(player) then
    return
  end

  if player and player.index then
    player_settings_cache[player.index] = nil
  end
end

function Settings.clear_all_caches()
  player_settings_cache = {}
end

function Settings:getPlayerSettings(player)
  return Settings.get_player_settings(player)
end

return Settings
