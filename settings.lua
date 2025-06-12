--[[
settings.lua
Handles per-player mod settings and access for TeleportFavorites.

Features:
- Provides a single entry point for retrieving all relevant per-player mod settings.
- Returns defaults if settings are not set or player is nil.
- Used by GUI and logic modules to determine user preferences and feature toggles.

API:
- Settings:getPlayerSettings(player): Returns a table of settings for the given player (or defaults).
  - teleport_radius (integer): Teleportation radius (default: Constants.settings.TELEPORT_RADIUS_DEFAULT)
  - favorites_on (boolean): Whether the favorites bar is enabled (default: true)
  - destination_msg_on (boolean): Whether to show destination messages (default: true)
--]]

local Constants = require("constants")

--- @class Settings
--- @field getPlayerSettings fun(self: Settings, player: LuaPlayer): table
local Settings = {}

--- Returns a table of per-player mod settings, with defaults if not set
--- @param player LuaPlayer|nil: The player to get settings for
--- @return table settings { teleport_radius: integer, favorites_on: boolean, destination_msg_on: boolean }
function Settings.getPlayerSettings(player)
  local settings = {
    teleport_radius = Constants.settings.TELEPORT_RADIUS_DEFAULT,
    favorites_on = true,
    destination_msg_on = true,
  }
  if not (player and player.mod_settings) then return settings end

  local mod_settings = player.mod_settings
  
  local t_radius = mod_settings["teleport-radius"]
  if t_radius and t_radius.value ~= nil then
    settings.teleport_radius = math.floor(tonumber(t_radius.value) or settings.teleport_radius)
  end

  local f_on = mod_settings["favorites-on"]
  if f_on and f_on.value ~= nil then settings.favorites_on = not not f_on.value end
  
    local dmsg = mod_settings["destination-msg-on"]
  if dmsg and dmsg.value ~= nil then settings.destination_msg_on = not not dmsg.value end
  
    return settings
end

return Settings

