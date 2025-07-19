---@diagnostic disable: undefined-doc-param, param-type-mismatch, missing-parameter, undefined-global

-- core/utils/teleport_strategy.lua
-- TeleportFavorites Factorio Mod
-- Strategy pattern implementation for extensible teleportation logic and scenario handling.

local GPSUtils = require("core.utils.gps_utils")
local ErrorHandler = require("core.utils.error_handler")
local LocaleUtils = require("core.utils.locale_utils")
local PositionUtils = require("core.utils.position_utils")
local ChartTagUtils = require("core.utils.chart_tag_utils")
local PlayerHelpers = require("core.utils.player_helpers")

local TeleportStrategy = {}

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

---@param player LuaPlayer Player to teleport
---@param gps string GPS coordinates in 'xxx.yyy.s' format
---@param context table? Optional teleportation context (e.g., {from_history_modal=true})
---@return boolean|string|integer
function TeleportStrategy.teleport_to_gps(player, gps, context)
  ErrorHandler.debug_log("Executing safe teleportation", {
    player_name = player and player.name or "nil",
    gps = gps,
    context = context
  })
  if not player or not player.valid then
    ErrorHandler.debug_log("Teleportation failed: Invalid player")
    return false, "invalid_player"
  end
  if not gps or type(gps) ~= "string" or gps == "" then
    ErrorHandler.debug_log("Teleportation failed: Invalid GPS", { gps = gps })
    return false, "invalid_gps"
  end

  local valid, error_msg = validate_prerequisites(player, gps)
  if not valid then
    ErrorHandler.debug_log("Safe teleport failed validation", { error = error_msg })
    return false, error_msg
  end

  local position, pos_error = get_landing_position(player, gps)
  if not player or not player.valid then
    ErrorHandler.debug_log("Teleportation failed: Invalid player")
    return false
  end
  if not gps or type(gps) ~= "string" or gps == "" then
    ErrorHandler.debug_log("Teleportation failed: Invalid GPS", { gps = gps })
    return false
  end

  local valid, error_msg = validate_prerequisites(player, gps)
  if not valid then
    ErrorHandler.debug_log("Safe teleport failed validation", { error = error_msg })
    return false
  end

  local position, pos_error = get_landing_position(player, gps)
  if not position or type(position.x) ~= "number" or type(position.y) ~= "number" then
    ErrorHandler.debug_log("Safe teleport failed position normalization", { error = pos_error })
    local error_message = pos_error or LocaleUtils.get_error_string(player, "position_normalization_failed")
    PlayerHelpers.safe_player_print(player, tostring(error_message))
    return false
  end

  local safety_radius = 16.0
  ---@type MapPosition
  local final_position = { x = position.x, y = position.y }
  local safe_position = find_safe_landing_position(player.surface, final_position, safety_radius, 0.5)
  if safe_position and type(safe_position.x) == "number" and type(safe_position.y) == "number" then
    final_position = { x = safe_position.x, y = safe_position.y }
    ErrorHandler.debug_log("Using optimized safe landing position", {
      original = position,
      safe = safe_position
    })
  end

  -- Ensure final_position is a plain MapPosition table for Factorio API
  final_position = { x = final_position.x, y = final_position.y }

  local teleport_success = false
  if player.physical_vehicle and player.physical_vehicle.valid then
    if player.physical_vehicle.speed == nil or player.physical_vehicle.speed == 0 then
      teleport_success = player.physical_vehicle.teleport(final_position, player.surface, false)
    else
      player.play_sound { path = "utility/cannot_build" }
      ErrorHandler.debug_log("Safe teleport blocked: Vehicle is moving")
      return false
    end
  else
    teleport_success = player.teleport(final_position, player.surface, true)
  end

  if teleport_success then
    ErrorHandler.debug_log("Safe teleportation successful", { final_position = final_position })
    if player.render_mode ~= defines.render_mode.game then
      player.exit_remote_view()
    end
    -- Only add to history if not from history modal
    if not (context and context.from_history_modal) then
      pcall(function()
        if remote.interfaces["TeleportFavorites_History"] and
            remote.interfaces["TeleportFavorites_History"].add_to_history then
          remote.call("TeleportFavorites_History", "add_to_history", player.index)
        end
      end)
    end
    return true
  end

  ErrorHandler.debug_log("Safe teleport failed: Unforeseen circumstances")
  return false
end


return TeleportStrategy
