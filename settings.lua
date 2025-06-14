--[[
settings.lua
TeleportFavorites Factorio Mod Settings Definition
-------------------------------------------------
Defines the mod settings that players can configure in the game's mod settings menu.
These settings are accessed via the settings_access module in the control stage.

Settings Defined:
- teleport-radius: Integer setting for teleportation search radius (1-32 tiles)
- favorites-on: Boolean setting to enable/disable the favorites bar
- destination-msg-on: Boolean setting to show/hide teleportation destination messages

Note: Settings defined here are automatically available in player.mod_settings 
during the control stage and can be accessed via the Settings module.
--]]

local Constants = require("constants")

data:extend({
  -- Teleport radius setting
  {
    type = "int-setting",
    name = "teleport-radius",
    setting_type = "runtime-per-user",
    default_value = Constants.settings.TELEPORT_RADIUS_DEFAULT,
    minimum_value = Constants.settings.TELEPORT_RADIUS_MIN,
    maximum_value = Constants.settings.TELEPORT_RADIUS_MAX,
    order = "a-teleport-radius"
  },
  
  -- Favorites bar enable/disable setting
  {
    type = "bool-setting",
    name = "favorites-on",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "b-favorites-on"
  },
  
  -- Destination message enable/disable setting
  {
    type = "bool-setting", 
    name = "destination-msg-on",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "c-destination-msg-on"
  }
})