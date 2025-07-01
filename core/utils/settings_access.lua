--[[
settings.lua
Handles per-player mod settings and access for TeleportFavorites.

Features:
- Provides a single entry point for retrieving all relevant per-player mod settings.
- Returns defaults if settings are not set or player is nil.
- Contains robust type checking and validation to ensure settings are within acceptable ranges.
- Used by GUI and logic modules to determine user preferences and feature toggles.

API:
- Settings:getPlayerSettings(player): Returns a table of settings for the given player (or defaults).
  - favorites_on (boolean): Whether the favorites bar is enabled (default: true)
  - show_player_coords (boolean): Whether to show player coordinates in favorites bar (default: true)
  -- map_reticle_on removed - functionality no longer exists
  -- teleport_radius removed - no longer needed
  -- destination_msg_on removed - messages always shown

Error Handling:
- Returns default values if player or player.mod_settings is nil
- Handles type conversion safely for all settings
- Enforces min/max boundaries for numeric settings
--]]

local Constants = require("constants")

--- @class Settings
--- @field getPlayerSettings fun(self: Settings, player: LuaPlayer): table
local Settings = {}

--- Returns a table of per-player mod settings, with defaults if not set
--- @param player LuaPlayer|nil The player to get settings for
--- @return table settings { favorites_on: boolean, show_player_coords: boolean }
function Settings:getPlayerSettings(player)-- Initialize with default values from Constants
  local settings = {
    favorites_on = true,
    show_player_coords = true,
    show_teleport_history = true,
    -- destination_msg_on removed - messages always shown
    -- map_reticle_on removed - functionality no longer exists
    -- teleport_radius removed - no longer needed
  }
  
  -- Return defaults if player or mod_settings are nil
  if not (player and player.mod_settings) then 
    return settings 
  end
  local mod_settings = player.mod_settings
  
  -- Get favorites on/off setting
  local f_on = mod_settings["favorites-on"]
  if f_on and f_on.value ~= nil then 
    -- Explicit boolean conversion using comparison
    if type(f_on.value) == "boolean" then
      settings.favorites_on = f_on.value
    else
      -- Default to true if not a boolean
      settings.favorites_on = true
    end
  end
    -- Get show player coordinates on/off setting
  local show_coords = mod_settings["show-player-coords"]
  if show_coords and show_coords.value ~= nil then 
    -- Explicit boolean conversion using comparison
    if type(show_coords.value) == "boolean" then
      settings.show_player_coords = show_coords.value
    else
      -- Default to true if not a boolean
      settings.show_player_coords = true
    end
  end
  
  -- Get show teleport history on/off setting
  local show_history = mod_settings["show-teleport-history"]
  if show_history and show_history.value ~= nil then
    -- Explicit boolean conversion using comparison
    if type(show_history.value) == "boolean" then
      settings.show_teleport_history = show_history.value
    else
      -- Default to true if not a boolean
      settings.show_teleport_history = true
    end
  end
  
  -- Destination message setting removed - messages always shown
  
  -- map reticle setting removed - functionality no longer exists
  
  return settings
end

--- Get the chart tag click radius for a player (with fallback to default)
--- @param player LuaPlayer
--- @return number click_radius
function Settings.get_chart_tag_click_radius(player)
  local default = tonumber(Constants.settings.CHART_TAG_CLICK_RADIUS) or 10
  if not player or not player.valid then return default end
  local player_settings = settings.get_player_settings(player)
  local setting = player_settings and player_settings["chart-tag-click-radius"]
  if setting and setting.value then
    local value = tonumber(setting.value)
    if value then return value end
  end
  return default
end

return Settings

