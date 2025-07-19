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
  
  -- Build settings using direct access to avoid circular dependency
  for setting_name, default_value in pairs(DEFAULT_SETTINGS) do
    if type(default_value) == "boolean" then
      -- Direct boolean setting access
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
  
  local setting = global_settings[setting_name]
  if setting and setting.value ~= nil then
    local value = tonumber(setting.value)
    if value then
      -- Apply range validation if specified
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

return Settings
