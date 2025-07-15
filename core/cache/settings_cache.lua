--[[
settings_cache.lua
Centralized settings cache and access layer for TeleportFavorites mod.

Responsibilities:
- Unified access to all Factorio settings (player mod settings and global runtime settings)
- Caching layer for performance optimization
- Type-safe validation with fallback defaults
- Single source of truth for all settings-related operations

Architecture:
- Part of the core/cache module family (alongside cache.lua, lookups.lua)
- Follows storage-as-source-of-truth pattern
- Provides consistent API for all settings access
- Handles both player-specific and global settings

API:
- SettingsCache.get_player_settings(player): Returns table of all cached player settings
- SettingsCache.get_boolean_setting(player, setting_name, default): Individual boolean setting
- SettingsCache.get_number_setting(player, setting_name, default, min, max): Individual number setting
- SettingsCache.get_chart_tag_click_radius(player): Specialized chart tag radius setting
- SettingsCache.invalidate_player_cache(player): Force refresh of cached settings

Design Principles:
- Cache-first approach for performance
- Consistent error handling with safe defaults
- Single path through Factorio's settings API
- Clear separation between different setting types
--]]

local Constants = require("constants")
local BasicHelpers = require("core.utils.basic_helpers")

--- @class SettingsCache
local SettingsCache = {}

-- Internal: Default settings configuration
local DEFAULT_SETTINGS = {
  favorites_on = true,
  show_player_coords = true,
  show_teleport_history = true,
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
      -- Map setting names to their actual mod setting identifiers
      local mod_setting_name = setting_name:gsub("_", "-")
      
      -- Direct boolean setting access
      if mod_settings then
        local setting = mod_settings[mod_setting_name]
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

--- Get a boolean setting for a player with safe defaults
--- @param player LuaPlayer|nil
--- @param setting_name string
--- @param default boolean
--- @return boolean
function SettingsCache.get_boolean_setting(player, setting_name, default)
  local mod_settings = get_player_mod_settings(player)
  if not mod_settings then
    return default
  end
  
  local setting = mod_settings[setting_name]
  if setting and setting.value ~= nil and type(setting.value) == "boolean" then
    return setting.value
  end
  
  return default
end

--- Get a number setting for a player with safe defaults and range validation
--- @param player LuaPlayer|nil
--- @param setting_name string
--- @param default number
--- @param min_value number|nil
--- @param max_value number|nil
--- @return number
function SettingsCache.get_number_setting(player, setting_name, default, min_value, max_value)
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
function SettingsCache.get_player_settings(player)
  if not BasicHelpers.is_valid_player(player) then
    return build_fresh_settings(nil) -- Return defaults for invalid player
  end
  
  local player_index = player.index
  
  -- Check cache first
  if is_cache_valid(player_index) then
    return player_settings_cache[player_index].settings
  end
  
  -- Build fresh settings and cache them
  local fresh_settings = build_fresh_settings(player)
  player_settings_cache[player_index] = {
    settings = fresh_settings,
    last_updated = game and game.tick or 0
  }
  
  return fresh_settings
end

--- Get the chart tag click radius for a player (with fallback to default)
--- Specialized method that uses global settings instead of player mod settings
--- @param player LuaPlayer|nil
--- @return number click_radius
function SettingsCache.get_chart_tag_click_radius(player)
  local default = 10 -- Safe fallback
  if Constants and Constants.settings and Constants.settings.CHART_TAG_CLICK_RADIUS then
    default = tonumber(Constants.settings.CHART_TAG_CLICK_RADIUS) or 10
  end
  return SettingsCache.get_number_setting(player, "chart-tag-click-radius", default, 1, 50)
end

--- Invalidate cached settings for a specific player
--- @param player LuaPlayer|nil
function SettingsCache.invalidate_player_cache(player)
  if not BasicHelpers.is_valid_player(player) then
    return
  end
  
  player_settings_cache[player.index] = nil
end

--- Clear all cached settings (useful for testing or major setting changes)
function SettingsCache.clear_all_caches()
  player_settings_cache = {}
end

--- Legacy compatibility layer for existing code
--- @deprecated Use SettingsCache.get_player_settings instead
--- @param player LuaPlayer|nil
--- @return table
function SettingsCache:getPlayerSettings(player)
  return SettingsCache.get_player_settings(player)
end

return SettingsCache
