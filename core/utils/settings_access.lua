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
  - teleport_radius (integer): Teleportation radius (default: Constants.settings.TELEPORT_RADIUS_DEFAULT)
                              Bounded by Constants.settings.TELEPORT_RADIUS_MIN and TELEPORT_RADIUS_MAX
  - favorites_on (boolean): Whether the favorites bar is enabled (default: true)
  - destination_msg_on (boolean): Whether to show destination messages (default: true)

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
--- @param self Settings
--- @param player LuaPlayer|nil The player to get settings for
--- @return table settings { teleport_radius: integer, favorites_on: boolean, destination_msg_on: boolean }
function Settings:getPlayerSettings(player)-- Initialize with default values from Constants
  local settings = {
    teleport_radius = Constants.settings.TELEPORT_RADIUS_DEFAULT,
    favorites_on = true,
    destination_msg_on = true,
    map_reticle_on = true,
  }
  
  -- Return defaults if player or mod_settings are nil
  if not (player and player.mod_settings) then 
    return settings 
  end

  local mod_settings = player.mod_settings
  -- Get teleport radius setting with validation
  local t_radius = mod_settings["teleport-radius"]
  if t_radius and t_radius.value ~= nil then
    -- Start with the default value as a number
    local radius_value = settings.teleport_radius
    
    -- Try to convert the setting value to a number if it's not nil
    if t_radius.value ~= nil then
      local converted = tonumber(t_radius.value)
      if converted ~= nil then
        -- If we successfully converted to a number, use it
        radius_value = math.floor(converted)
      end
    end
    
    -- Manually enforce the min/max bounds for type safety
    -- These are defined in constants.lua as numbers already
    local min = Constants.settings.TELEPORT_RADIUS_MIN
    if type(min) == "number" and radius_value < min then
      radius_value = min
    end
    
    local max = Constants.settings.TELEPORT_RADIUS_MAX
    if type(max) == "number" and radius_value > max then
      radius_value = max
    end
    
    settings.teleport_radius = radius_value
  end
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
    end
  end
  
  -- Get map reticle on/off setting
  local reticle = mod_settings["map-reticle-on"]
  if reticle and reticle.value ~= nil then 
    -- Explicit boolean conversion using comparison
    if type(reticle.value) == "boolean" then
      settings.map_reticle_on = reticle.value
    else
      -- Default to true if not a boolean
      settings.map_reticle_on = true
    end
  end
  
  return settings
end

return Settings

