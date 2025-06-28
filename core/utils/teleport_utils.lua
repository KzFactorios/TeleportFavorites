-- teleport_utils.lua
-- Shared teleportation logic for Tag and GameHelpers to break circular dependency

local TeleportStrategies = require("core.utils.teleport_strategy")
local ErrorHandler = require("core.utils.error_handler")
local Enum = require("prototypes.enums.enum")

local TeleportUtils = {}

--- Teleport player to GPS location using strategy pattern with comprehensive error handling
---@param player LuaPlayer Player to teleport
---@param gps string GPS coordinates in 'xxx.yyy.s' format
---@param context table? Optional teleportation context
---@param return_raw boolean? If true, return raw result (string|integer), else boolean
---@return boolean|string|integer
function TeleportUtils.teleport_to_gps(player, gps, context, return_raw)
  if not player or not player.valid then
    ErrorHandler.debug_log("Teleportation failed: Invalid player")
    if return_raw then return "invalid_player" end
    return false
  end
  if not gps or type(gps) ~= "string" or gps == "" then
    ErrorHandler.debug_log("Teleportation failed: Invalid GPS", { gps = gps })
    if return_raw then return "invalid_gps" end
    return false
  end
  local result = TeleportStrategies.TeleportStrategyManager.execute_teleport(player, gps, context)
  if return_raw then
    if type(result) == "string" or type(result) == "number" then
      return result
    else
      return "teleport_failed"
    end
  else
    if result == Enum.ReturnStateEnum.SUCCESS then
      return true
    else
      return false
    end
  end
end

return TeleportUtils
