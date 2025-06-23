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
  - destination_msg_on (boolean): Whether to show destination messages (default: true)
  -- map_reticle_on removed - functionality no longer exists
  -- teleport_radius removed - no longer needed

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
--- @return table settings { favorites_on: boolean, destination_msg_on: boolean }
function Settings:getPlayerSettings(player)-- Initialize with default values from Constants
  local settings = {
    favorites_on = true,
    destination_msg_on = true,
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
    -- Get destination message on/off setting
  local dmsg = mod_settings["destination-msg-on"]
  if dmsg and dmsg.value ~= nil then 
    -- Explicit boolean conversion using comparison
    if type(dmsg.value) == "boolean" then
      settings.destination_msg_on = dmsg.value
    else
      -- Default to true if not a boolean
      settings.destination_msg_on = true
    end  end
  
  -- map reticle setting removed - functionality no longer exists
  
  return settings
end

return Settings

