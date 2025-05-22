-- settings.lua
-- Handles per-player settings and access

--- @class Settings
--- @field getPlayerSettings fun(self: Settings, player: LuaPlayer): table
local Settings = {}

local Constants = require("constants")

--- Returns a table of per-player mod settings, with defaults if not set
-- @param player LuaPlayer|nil
-- @return table settings { teleport_radius: integer, favorites_on: boolean, destination_msg_on: boolean }
function Settings:getPlayerSettings(player)
  local settings = {
    teleport_radius = Constants.TELEPORT_RADIUS_DEFAULT,
    favorites_on = true,
    destination_msg_on = true,
  }

  if not player or not player.mod_settings then
    return settings
  end

  local mod_settings = player.mod_settings
  ---@cast mod_settings table<string, {value: any}>  -- EmmyLua type cast for static analysis

  local t_radius = mod_settings["teleport-radius"]
  if t_radius and t_radius.value ~= nil then
    settings.teleport_radius = math.floor(tonumber(t_radius.value) or Constants.TELEPORT_RADIUS_DEFAULT)
  end

  local favorites_on = mod_settings["favorites-on"]
  if favorites_on and favorites_on.value ~= nil then
    ---@cast favorites_on { value: boolean }
    settings.favorites_on = not not favorites_on.value
  end

  local destination_msg_on = mod_settings["destination-msg-on"]
  if destination_msg_on and destination_msg_on.value ~= nil then
    ---@cast destination_msg_on { value: boolean }
    settings.destination_msg_on = not not destination_msg_on.value
  end

  return settings
end

return Settings

