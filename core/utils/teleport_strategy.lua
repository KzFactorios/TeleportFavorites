---@diagnostic disable: undefined-doc-param, param-type-mismatch, missing-parameter, undefined-global

-- core/utils/teleport_strategy.lua
-- TeleportFavorites Factorio Mod
-- Strategy pattern implementation for extensible teleportation logic and scenario handling.

local GPSUtils = require("core.utils.gps_utils")
local ErrorHandler = require("core.utils.error_handler")
local LocaleUtils = require("core.utils.locale_utils")
local BasicHelpers = require("core.utils.basic_helpers")
local Cache = require("core.cache.cache")
local TeleportHistory = require("core.teleport.teleport_history")

local TeleportStrategy = {}


---@param player LuaPlayer
---@return boolean, string
local function validate_prerequisites(player)
  if not player or not player.valid then
    return false, LocaleUtils.get_error_string(player, "player_missing")
  end
  if not player.character then
    return false, LocaleUtils.get_error_string(player, "player_character_missing")
  end
  return true, ""
end

---@param player LuaPlayer
---@param position MapPosition
---@param surface LuaSurface
---@return boolean success
---@return string? error_code
local function teleport_entity_to_position(player, position, surface)
  if player.physical_vehicle and player.physical_vehicle.valid then
    if player.physical_vehicle.speed == nil or player.physical_vehicle.speed == 0 then
      return player.physical_vehicle.teleport(position, surface, true), nil
    end

    player.play_sound { path = "utility/cannot_build" }
    ErrorHandler.warn_log("Safe teleport blocked: Vehicle is moving")
    return false, "vehicle_moving"
  end

  return player.teleport(position, surface, true), nil
end

---@param target_position MapPosition
---@return MapPosition[]
local function build_fast_fallback_positions(target_position)
  return {
    { x = target_position.x + 1, y = target_position.y },
    { x = target_position.x - 1, y = target_position.y },
    { x = target_position.x, y = target_position.y + 1 },
    { x = target_position.x, y = target_position.y - 1 },
  }
end

---@param player LuaPlayer Player to teleport
---@param gps string GPS coordinates in 'xxx.yyy.s' format
---@param add_to_history boolean? Whether to add the teleport to history (default true)
---@return boolean, string -- Final status and GPS string or error code
function TeleportStrategy.teleport_to_gps(player, target_gps, add_to_history)
  if add_to_history == nil then add_to_history = true end

  if ErrorHandler.should_log_debug() then
    ErrorHandler.debug_log("Executing safe teleportation", {
      player_name = player and player.name or "nil",
      target_gps = target_gps,
      add_to_history = add_to_history
    })
  end
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

  local parsed_target_gps = GPSUtils.parse_gps_string(target_gps)
  if not parsed_target_gps then
    ErrorHandler.error_log("TeleportStrategy", "Teleportation failed: Malformed GPS", { target_gps = target_gps },
      "teleport_to_gps")
    return false, "invalid_gps"
  end

  local target_surface_index = math.floor(parsed_target_gps.s)
  local target_position = { x = parsed_target_gps.x, y = parsed_target_gps.y }
  local normalized_target_gps = GPSUtils.gps_from_map_position(target_position, target_surface_index)
  local target_surface = target_surface_index and game.surfaces[target_surface_index] or nil
  if not target_surface or not target_surface.valid then
    ErrorHandler.error_log("TeleportStrategy", "Teleportation failed: Invalid target surface", {
      target_gps = target_gps,
      target_surface_index = target_surface_index
    }, "teleport_to_gps")
    return false, "invalid_target_surface"
  end

  -- Short-circuit if player is already at the target GPS position (surface-aware, multiplayer-safe)
  local player_surface_index = player.surface and player.surface.valid and player.surface.index or nil
  local is_same_surface = player_surface_index and player_surface_index == target_surface_index
  if is_same_surface and player.position and type(player.position.x) == "number" and type(player.position.y) == "number" then
    local rounded_x = math.floor(player.position.x + 0.5)
    local rounded_y = math.floor(player.position.y + 0.5)
    if rounded_x == parsed_target_gps.x and rounded_y == parsed_target_gps.y then
      if ErrorHandler.should_log_debug() then
        ErrorHandler.debug_log("Teleport short-circuited: Already at target GPS", {
          target_gps = normalized_target_gps
        })
      end
      return false, "already_at_target"
    end
  end

  local from_gps = nil
  if add_to_history and Cache.get_sequential_history_mode(player) then
    if player.position and type(player.position.x) == "number" and type(player.position.y) == "number" and player_surface_index then
      from_gps = GPSUtils.gps_from_map_position(player.position, player_surface_index)
    end
  end

  local working_position = target_position
  local working_gps = normalized_target_gps

  local teleport_success, teleport_error = teleport_entity_to_position(player, working_position, target_surface)
  if not teleport_success and teleport_error == "vehicle_moving" then
    return false, teleport_error
  end

  if not teleport_success then
    local fallback_positions = build_fast_fallback_positions(target_position)
    for _, fallback_position in ipairs(fallback_positions) do
      working_position = fallback_position
      working_gps = GPSUtils.gps_from_map_position(fallback_position, tonumber(target_surface.index) or 1)
      teleport_success, teleport_error = teleport_entity_to_position(player, working_position, target_surface)
      if teleport_success then
        break
      end
      if teleport_error == "vehicle_moving" then
        return false, teleport_error
      end
    end
  end

  if not teleport_success then
    local search_radius = 4.0
    local precision = 0.5
    local non_collide_position = target_surface.find_non_colliding_position("character", target_position, search_radius, precision)

    if not non_collide_position or type(non_collide_position.x) ~= "number" or type(non_collide_position.y) ~= "number" then
      ErrorHandler.error_log("TeleportStrategy", "Safe teleport failed: No valid safe landing position", {}, "teleport_to_gps")
      BasicHelpers.safe_player_print(player, LocaleUtils.get_error_string(player, "no_safe_landing_position"))
      return false, "no_safe_landing_position"
    end

    working_position = non_collide_position
    working_gps = GPSUtils.gps_from_map_position(non_collide_position, tonumber(target_surface.index) or 1)
    teleport_success, teleport_error = teleport_entity_to_position(player, working_position, target_surface)
    if not teleport_success and teleport_error == "vehicle_moving" then
      return false, teleport_error
    end
  end

  if teleport_success then
    -- MULTIPLAYER FIX: render_mode is client-specific and causes desyncs.
    -- Use controller_type which is deterministic game state.
    if player.controller_type == defines.controllers.remote then
      player.exit_remote_view()
    end

    if add_to_history then
      TeleportHistory.add_teleport(player, from_gps, working_gps)
    end
    return true, working_gps
  end

  ErrorHandler.error_log("TeleportStrategy", "Safe teleport failed: Unforeseen circumstances", {}, "teleport_to_gps")
  return false, "teleport_failed"
end

return TeleportStrategy
