---@diagnostic disable: undefined-global

-- core/cache/settings.lua
-- TeleportFavorites Factorio Mod
-- Centralized settings cache and access layer for unified, type-safe Factorio settings management.

local Deps = require("base_deps")
local BasicHelpers, Constants = Deps.BasicHelpers, Deps.Constants

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

-- Internal: Cache for max-favorite-slots per player (rarely changes — only via settings menu)
-- Uses the same 1-minute TTL as the broader settings cache.
local max_slots_cache = {}

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


--- Get per-player max favorite slots as a number (10, 20, or 30).
--- Result is cached for CACHE_INVALIDATION_INTERVAL ticks; the setting only
--- changes when the player explicitly visits the mod-settings menu.
--- @param player LuaPlayer|nil
--- @return integer
function Settings.get_player_max_favorite_slots(player)
  local default_slots = math.floor(tonumber(Constants.settings.DEFAULT_MAX_FAVORITE_SLOTS) or 10)
  local player_index  = player and player.index

  -- Fast-path: serve from cache when still fresh.
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

--- Invalidate the max-slots cache for a player (call after settings-changed event).
--- @param player_index integer|nil  nil = clear all
function Settings.invalidate_max_slots_cache(player_index)
  if player_index then
    max_slots_cache[player_index] = nil
  else
    max_slots_cache = {}
  end
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

--- Returns the chart tag click radius in tiles.
--- Controlled by Constants.settings.CHART_TAG_CLICK_RADIUS; not user-configurable.
--- @return number
function Settings.get_chart_tag_click_radius()
  return math.floor(tonumber(Constants.settings.CHART_TAG_CLICK_RADIUS) or 10)
end

--- Invalidate cached settings for a specific player
--- @param player LuaPlayer|nil
function Settings.invalidate_player_cache(player)
  if not BasicHelpers.is_valid_player(player) then
    return
  end
  
  if player and player.index then
    player_settings_cache[player.index] = nil
    Settings.invalidate_max_slots_cache(player.index)
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
