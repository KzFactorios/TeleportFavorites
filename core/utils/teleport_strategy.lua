---@diagnostic disable: undefined-doc-param, param-type-mismatch, missing-parameter
-- core/utils/teleport_strategy.lua
-- TeleportFavorites Factorio Mod
-- Strategy pattern implementation for extensible teleportation logic and scenario handling.


local GPSUtils = require("core.utils.gps_utils")
local ErrorHandler = require("core.utils.error_handler")
local Enum = require("prototypes.enums.enum")
local LocaleUtils = require("core.utils.locale_utils")
local PositionUtils = require("core.utils.position_utils")
local ChartTagUtils = require("core.utils.chart_tag_utils")
local PlayerHelpers = require("core.utils.player_helpers")

local TeleportUtils = {}

local function find_safe_landing_position(surface, position, radius, precision)
  return PositionUtils.find_safe_landing_position(surface, position, radius, precision)
end

local function validate_prerequisites(player, gps)
  if not player or not player.valid then
    return false, LocaleUtils.get_error_string(player, "player_missing")
  end
  if not player.character then
    return false, LocaleUtils.get_error_string(player, "player_character_missing")
  end
  return true, ""
end

local function get_landing_position(player, gps)
  local position = GPSUtils.map_position_from_gps(gps)
  if not position then
    return nil, LocaleUtils.get_error_string(player, "invalid_gps_format")
  end
  local chart_tag = ChartTagUtils.find_closest_chart_tag_to_position(player, position)
  if chart_tag and chart_tag.position then
    return chart_tag.position, ""
  end
  if type(position) == "table" and position.x and position.y then
    return position, ""
  end
  return nil, LocaleUtils.get_error_string(player, "invalid_map_position")
end

--- Teleport player to GPS location using safe teleportation logic only
---@param player LuaPlayer Player to teleport
---@param gps string GPS coordinates in 'xxx.yyy.s' format
---@param context table? Optional teleportation context
---@param return_raw boolean? If true, return raw result (string|integer), else boolean
---@return boolean|string|integer
function TeleportUtils.teleport_to_gps(player, gps, return_raw)
  ErrorHandler.debug_log("Executing safe teleportation", {
    player_name = player and player.name or "nil",
    gps = gps
  })
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

  local valid, error_msg = validate_prerequisites(player, gps)
  if not valid then
    ErrorHandler.debug_log("Safe teleport failed validation", { error = error_msg })
    if return_raw then return error_msg or LocaleUtils.get_error_string(player, "validation_failed") end
    return false
  end

  local position, pos_error = get_landing_position(player, gps)
  if not position then
    ErrorHandler.debug_log("Safe teleport failed position normalization", { error = pos_error })
    local error_message = pos_error or LocaleUtils.get_error_string(player, "position_normalization_failed")
    PlayerHelpers.safe_player_print(player, tostring(error_message))
    if return_raw then return tostring(error_message) end
    return false
  end

  local safety_radius = 16.0
  local final_position = position
  local safe_position = find_safe_landing_position(player.surface, position, safety_radius, 0.5)
  if safe_position and type(safe_position) == "table" and safe_position.x and safe_position.y then
    final_position = safe_position
    ErrorHandler.debug_log("Using optimized safe landing position", {
      original = position,
      safe = safe_position
    })
  end

  local teleport_success = false

  if player.physical_vehicle and player.physical_vehicle.valid then
    local riding_state = player.riding_state and player.riding_state.acceleration or nil
    if player.physical_vehicle.speed == nil or player.physical_vehicle.speed == 0 then
      if type(final_position) == "table" and final_position.x and final_position.y then
        player.physical_vehicle.teleport(final_position, player.surface, false)
        teleport_success = player.teleport(final_position, player.surface, true)
      else
        ErrorHandler.debug_log("Safe teleport failed: Invalid final_position for vehicle teleport", { final_position = final_position })
        if return_raw then return LocaleUtils.get_error_string(player, "invalid_map_position") end
        return false
      end
    else
      player.play_sound { path = "utility/cannot_build" }
      ErrorHandler.debug_log("Safe teleport blocked: Vehicle is moving", { riding_state = riding_state })
      if return_raw then return LocaleUtils.get_error_string(player, "teleport_blocked_driving") end
      return false
    end
  else
    if type(final_position) == "table" and final_position.x and final_position.y then
      teleport_success = player.teleport(final_position, player.surface, true)
    else
      ErrorHandler.debug_log("Safe teleport failed: Invalid final_position for player teleport", { final_position = final_position })
      if return_raw then return LocaleUtils.get_error_string(player, "invalid_map_position") end
      return false
    end
  end

  if teleport_success then
    ErrorHandler.debug_log("Safe teleportation successful", { final_position = final_position })
    if player.render_mode ~= defines.render_mode.game then
      player.exit_remote_view()
    end
    if return_raw then return Enum.ReturnStateEnum.SUCCESS end
    pcall(function()
      if remote.interfaces["TeleportFavorites_History"] and
          remote.interfaces["TeleportFavorites_History"].add_to_history then
        remote.call("TeleportFavorites_History", "add_to_history", player.index)
      end
    end)
    return true
  end

  ErrorHandler.debug_log("Safe teleport failed: Unforeseen circumstances")
  if return_raw then return LocaleUtils.get_error_string(player, "safe_teleport_unforeseen_error") end
  return false
end

return {
  TeleportUtils = TeleportUtils
}
