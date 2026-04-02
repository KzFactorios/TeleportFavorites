---@diagnostic disable: undefined-global

-- core/cache/settings.lua
-- TeleportFavorites Factorio Mod
-- Centralized settings cache and access layer for unified, type-safe Factorio settings management.

local Constants = require("constants")
local BasicHelpers = require("core.utils.basic_helpers")

--- @class Settings
local Settings = {}

-- Internal: Default settings configuration
local DEFAULT_SETTINGS = {
  favorites_on = true,
  enable_teleport_history = true,
}

-- Internal: Player settings cache
-- Format: cache[player_index] = { settings_table, last_updated }
local player_settings_cache = {}

-- Internal: Cache invalidation interval (in ticks)
local CACHE_INVALIDATION_INTERVAL = 3600 -- 1 minute at 60 UPS

-- Internal: Safe access to player mod settings
local function get_player_mod_settings(player)
  if not BasicHelpers.is_valid_player(player) then
    return nil
  end
  return player.mod_settings
end

-- Internal: Safe access to global settings
local function get_global_settings(player)
  if not BasicHelpers.is_valid_player(player) then
    return nil
  end
  return settings.get_player_settings(player)
end

-- Internal: Check if cached settings are still valid
local function is_cache_valid(player_index)
  local cached = player_settings_cache[player_index]
  if not cached then
    return false
  end
  
  local current_tick = game and game.tick or 0
  return (current_tick - cached.last_updated) < CACHE_INVALIDATION_INTERVAL
end

-- Internal: Build fresh settings table for a player
local function build_fresh_settings(player)
  local settings_table = {}
  local mod_settings = get_player_mod_settings(player)

  -- Boolean settings (favorites_on, enable_teleport_history)
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

  -- Max favorite slots (per-user string setting "10" | "20" | "30")
  local default_slots = math.floor(tonumber(Constants.settings.DEFAULT_MAX_FAVORITE_SLOTS) or 10)
  local max_slots_key = Constants.settings.MAX_FAVORITE_SLOTS_SETTING
  if mod_settings and max_slots_key then
    local s = mod_settings[max_slots_key]
    local n = s and tonumber(s.value) or nil
    settings_table.max_favorite_slots = (n == 10 or n == 20 or n == 30) and math.floor(n) or default_slots
  else
    settings_table.max_favorite_slots = default_slots
  end

  -- Slot label mode (per-user string setting "off" | "short" | "long")
  local default_mode = Constants.settings.DEFAULT_SLOT_LABEL_MODE or "off"
  local label_key = Constants.settings.SLOT_LABEL_MODE_SETTING
  if mod_settings and label_key then
    local s = mod_settings[label_key]
    local v = s and s.value or nil
    settings_table.slot_label_mode = (v == "short" or v == "long") and v or default_mode
  else
    settings_table.slot_label_mode = default_mode
  end

  return settings_table
end

--- Get a number setting for a player with safe defaults and range validation
--- @param player LuaPlayer|nil
--- @param setting_name string
--- @param default number
--- @param min_value number|nil
--- @param max_value number|nil
--- @return number
function Settings.get_number_setting(player, setting_name, default, min_value, max_value)
  local global_settings = get_global_settings(player)
  if not global_settings then
    return default
  end

  -- TODO debate on wether or not to have a player-specific setting
  
  return default
end

--- Get per-player max favorite slots as a number (10, 20, or 30)
--- @param player LuaPlayer|nil
--- @return integer
function Settings.get_player_max_favorite_slots(player)
  local cached = Settings.get_player_settings(player)
  return cached.max_favorite_slots
    or math.floor(tonumber(Constants.settings.DEFAULT_MAX_FAVORITE_SLOTS) or 10)
end

--- Returns a table of all per-player mod settings with caching
--- @param player LuaPlayer|nil The player to get settings for
--- @return table settings Complete settings table with all values
function Settings.get_player_settings(player)
  if not BasicHelpers.is_valid_player(player) then
    return build_fresh_settings(nil) -- Return defaults for invalid player
  end
  
  local player_index = (player and player.index) or nil
  
  -- Check cache first
  if player_index and is_cache_valid(player_index) then
    return player_settings_cache[player_index].settings
  end
  
  -- Build fresh settings and cache them
  local fresh_settings = build_fresh_settings(player)
  if player_index then
    player_settings_cache[player_index] = {
      settings = fresh_settings,
      last_updated = game and game.tick or 0
    }
  end
  
  return fresh_settings
end

--- Get the chart tag click radius for a player (with fallback to default)
--- Specialized method that uses global settings instead of player mod settings
--- @param player LuaPlayer|nil
--- @return number click_radius
function Settings.get_chart_tag_click_radius(player)
  local default = 10 -- Safe fallback
  if Constants and Constants.settings and Constants.settings.CHART_TAG_CLICK_RADIUS then
    default = math.floor(tonumber(Constants.settings.CHART_TAG_CLICK_RADIUS) or 10)
  end
  return Settings.get_number_setting(player, "chart-tag-click-radius", default, 1, 50)
end

--- Invalidate cached settings for a specific player
--- @param player LuaPlayer|nil
function Settings.invalidate_player_cache(player)
  if not BasicHelpers.is_valid_player(player) then
    return
  end
  
  if player and player.index then
    player_settings_cache[player.index] = nil
  end
end

--- Clear all cached settings (useful for testing or major setting changes)
function Settings.clear_all_caches()
  player_settings_cache = {}
end

--- Legacy compatibility layer for existing code
--- @deprecated Use Settings.get_player_settings instead
--- @param player LuaPlayer|nil
--- @return table
function Settings:getPlayerSettings(player)
  return Settings.get_player_settings(player)
end

--- Get per-player slot label mode ("off", "short", or "long")
--- @param player LuaPlayer|nil
--- @return string mode "off", "short", or "long"
function Settings.get_player_slot_label_mode(player)
  local cached = Settings.get_player_settings(player)
  return cached.slot_label_mode
    or Constants.settings.DEFAULT_SLOT_LABEL_MODE or "off"
end

return Settings
