local Deps = require("core.base_deps_barrel")
local BasicHelpers, Constants = Deps.BasicHelpers, Deps.Constants
local Settings = {}
local DEFAULT_SETTINGS = {
  favorites_on = true,
  enable_teleport_history = true,
}
local player_settings_cache = {}
local CACHE_INVALIDATION_INTERVAL = 3600
local max_slots_cache = {}
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
function Settings.get_player_max_favorite_slots(player)
  local default_slots = math.floor(tonumber(Constants.settings.DEFAULT_MAX_FAVORITE_SLOTS) or 10)
  local player_index  = player and player.index
  if player_index then
    local cached = max_slots_cache[player_index]
    if cached then
      local tick = game and game.tick or 0
      if (tick - cached.tick) < CACHE_INVALIDATION_INTERVAL then
        return cached.value
      end
    end
  end
  local setting_key = Constants and Constants.settings and Constants.settings.MAX_FAVORITE_SLOTS_SETTING or nil
  if not setting_key then return default_slots end
  local global_settings = get_global_settings(player)
  if not global_settings then return default_slots end
  local s     = global_settings[setting_key]
  local value = s and s.value or nil
  local result = default_slots
  if type(value) == "string" then
    local n = tonumber(value)
    if n == 10 or n == 20 or n == 30 then result = math.floor(n) end
  elseif type(value) == "number" then
    local n = math.floor(value)
    if n == 10 or n == 20 or n == 30 then result = n end
  end
  if player_index then
    max_slots_cache[player_index] = { value = result, tick = game and game.tick or 0 }
  end
  return result
end
function Settings.invalidate_max_slots_cache(player_index)
  if player_index then
    max_slots_cache[player_index] = nil
  else
    max_slots_cache = {}
  end
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
function Settings.get_chart_tag_click_radius()
  return math.floor(tonumber(Constants.settings.CHART_TAG_CLICK_RADIUS) or 10)
end
function Settings.invalidate_player_cache(player)
  if not BasicHelpers.is_valid_player(player) then
    return
  end
  if player and player.index then
    player_settings_cache[player.index] = nil
    Settings.invalidate_max_slots_cache(player.index)
  end
end
function Settings:getPlayerSettings(player)
  return Settings.get_player_settings(player)
end
function Settings.get_player_slot_label_mode(player)
  local default_mode = Constants.settings.DEFAULT_SLOT_LABEL_MODE or "off"
  local setting_key = Constants.settings.SLOT_LABEL_MODE_SETTING
  if not setting_key then return default_mode end
  local global_settings = get_global_settings(player)
  if not global_settings then return default_mode end
  local s = global_settings[setting_key]
  local value = s and s.value or nil
  if value == "short" or value == "long" then
    return value
  end
  return default_mode
end
return Settings
