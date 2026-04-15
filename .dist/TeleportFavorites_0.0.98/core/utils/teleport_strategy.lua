local Deps = require("core.deps_barrel")
local BasicHelpers, ErrorHandler, Cache, Constants, GPSUtils =
  Deps.BasicHelpers, Deps.ErrorHandler, Deps.Cache, Deps.Constants, Deps.GpsUtils
local ChartTagUtils = require("core.utils.chart_tag_utils")
local TeleportStrategy = {}
local function validate_prerequisites(player)
  if not player.character then
    return false, BasicHelpers.get_error_string(player, "player_character_missing")
  end
  return true, ""
end
local function get_closest_chart_tag_gps(player, gps)
  if not gps then return nil end
  local chart_tag = Cache.Lookups.get_chart_tag_by_gps(gps) or nil
  if not chart_tag or not chart_tag.valid then
    local pos = GPSUtils.map_position_from_gps(gps)
    if not pos or type(pos.x) ~= "number" or type(pos.y) ~= "number" then
      ErrorHandler.error_log("TeleportStrategy", "Invalid MapPosition for chart tag search", { gps = gps }, "get_closest_chart_tag_gps")
      return nil
    end
    chart_tag = ChartTagUtils.find_closest_chart_tag_to_position(player, pos)
  end
  if chart_tag and chart_tag.position and type(chart_tag.position.x) == "number" and type(chart_tag.position.y) == "number" then
  local surface_index = player.surface.index
  return GPSUtils.gps_from_map_position(chart_tag.position, surface_index)
  end
  return nil
end
function TeleportStrategy.teleport_to_gps(player, target_gps, add_to_history, action_id)
  if add_to_history == nil then add_to_history = true end
  ErrorHandler.debug_log("Executing safe teleportation", {
    player_name = player and player.name or "nil",
    target_gps = target_gps,
    add_to_history = add_to_history
  })
  if not player or not player.valid then
  ErrorHandler.error_log("TeleportStrategy", "Teleportation failed: Invalid player", {}, "teleport_to_gps")
    return false, "invalid_player"
  end
  if not target_gps or type(target_gps) ~= "string" or target_gps == "" then
  ErrorHandler.error_log("TeleportStrategy", "Teleportation failed: Invalid GPS", {}, "teleport_to_gps")
    return false, "invalid_gps"
  end
  local valid, error_msg = validate_prerequisites(player)
  if not valid then
    ErrorHandler.warn_log("Safe teleport failed validation", { error = error_msg })
    return false, error_msg
  end
  local target_position = GPSUtils.map_position_from_gps(target_gps)
  local player_gps = nil
  if player.position and type(player.position.x) == "number" and type(player.position.y) == "number" then
  local surface_index = player.surface.index
  player_gps = GPSUtils.gps_from_map_position(player.position, surface_index)
  end
  if target_gps == player_gps then
    ErrorHandler.debug_log("Teleport short-circuited: Already at target GPS", {
      player_gps = player_gps,
      target_gps = target_gps
    })
    return false, "already_at_target"
  end
  local working_gps = get_closest_chart_tag_gps(player, target_gps)
  if not working_gps or working_gps == Constants.settings.BLANK_GPS then
    local search_radius = 4.0
    local precision = 0.5
    local safe_target_position = (target_position and type(target_position.x) == "number" and type(target_position.y) == "number") and target_position or {x=0, y=0}
    local non_collide_position = nil
    if safe_target_position and type(safe_target_position.x) == "number" and type(safe_target_position.y) == "number" then
      non_collide_position = player.surface.find_non_colliding_position("character", safe_target_position, search_radius, precision)
    end
    if non_collide_position and type(non_collide_position.x) == "number" and type(non_collide_position.y) == "number" then
      working_gps = GPSUtils.gps_from_map_position(non_collide_position, tonumber(player.surface.index) or 1)
    end
  end
  if not working_gps then
    ErrorHandler.error_log("TeleportStrategy", "Safe teleport failed: No valid safe landing position", {}, "teleport_to_gps")
    BasicHelpers.safe_player_print(player, BasicHelpers.get_error_string(player, "no_safe_landing_position"))
    return false, "no_safe_landing_position"
  end
  local working_position = GPSUtils.map_position_from_gps(working_gps)
  if not working_position then
  ErrorHandler.error_log("TeleportStrategy", "Safe teleport failed: Invalid working position", {}, "teleport_to_gps")
  BasicHelpers.safe_player_print(player, BasicHelpers.get_error_string(player, "invalid_working_position"))
    return false, "invalid_working_position"
  end
  local teleport_success = false
  if player.physical_vehicle and player.physical_vehicle.valid then
    if player.physical_vehicle.speed == nil or player.physical_vehicle.speed == 0 then
      teleport_success = player.physical_vehicle.teleport(working_position, player.surface, true)
    else
      player.play_sound { path = "utility/cannot_build" }
      ErrorHandler.warn_log("Safe teleport blocked: Vehicle is moving")
      return false, "vehicle_moving"
    end
  else
    teleport_success = player.teleport(working_position, player.surface, true)
  end
  if teleport_success then
    if player.controller_type == defines.controllers.remote then
      player.exit_remote_view()
    end
    if add_to_history then
      local ok, result = pcall(function()
        if remote.interfaces["TeleportFavorites_History"] and
            remote.interfaces["TeleportFavorites_History"].add_teleport then
          remote.call("TeleportFavorites_History", "add_teleport", player.index, player_gps, working_gps)
        end
      end)
    end
    return true, working_gps
  end
  ErrorHandler.error_log("TeleportStrategy", "Safe teleport failed: Unforeseen circumstances", {}, "teleport_to_gps")
  return false, "teleport_failed"
end
return TeleportStrategy
