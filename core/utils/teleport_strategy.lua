---@diagnostic disable: undefined-doc-param, param-type-mismatch, missing-parameter, undefined-global

-- core/utils/teleport_strategy.lua
-- TeleportFavorites Factorio Mod
-- Strategy pattern implementation for extensible teleportation logic and scenario handling.

local Deps = require("core.deps_barrel")
local BasicHelpers, ErrorHandler, Cache, Constants, GPSUtils =
  Deps.BasicHelpers, Deps.ErrorHandler, Deps.Cache, Deps.Constants, Deps.GpsUtils
local ChartTagUtils = require("core.utils.chart_tag_utils")

local TeleportStrategy = {}

--- Character/camera split in remote view: player.position is the map camera;
--- physical_position (2.1+) or character.position is where the body actually is.
---@param player LuaPlayer
---@return MapPosition|nil position
---@return integer|nil surface_index
local function get_physical_location(player)
  if not player or not player.valid then return nil, nil end

  local pos = nil
  local surface_index = nil

  if player.physical_position
      and type(player.physical_position.x) == "number"
      and type(player.physical_position.y) == "number" then
    pos = player.physical_position
    if player.physical_surface_index then
      surface_index = math.floor(tonumber(player.physical_surface_index) or 0)
    elseif player.physical_surface and player.physical_surface.valid then
      surface_index = player.physical_surface.index
    end
  end

  if not pos and player.character and player.character.valid
      and player.character.position
      and type(player.character.position.x) == "number"
      and type(player.character.position.y) == "number" then
    pos = player.character.position
    if player.character.surface and player.character.surface.valid then
      surface_index = player.character.surface.index
    end
  end

  if not pos and player.position
      and type(player.position.x) == "number"
      and type(player.position.y) == "number" then
    pos = player.position
    if player.surface and player.surface.valid then
      surface_index = player.surface.index
    end
  end

  if surface_index then
    surface_index = math.floor(tonumber(surface_index) or 1)
  end

  return pos, surface_index
end

---@param surface_index integer|nil
---@param fallback LuaSurface|nil
---@return LuaSurface|nil
local function resolve_target_surface(surface_index, fallback)
  if surface_index then
    surface_index = math.floor(tonumber(surface_index) or 0)
    if surface_index >= 1 and game and game.get_surface then
      local surface = game.get_surface(surface_index)
      if surface and surface.valid then return surface end
    end
  end
  if fallback and fallback.valid then return fallback end
  return nil
end

---@param gps_a string|nil
---@param gps_b string|nil
---@return boolean
local function gps_coords_equal(gps_a, gps_b)
  if not gps_a or not gps_b then return false end
  if gps_a == gps_b then return true end
  local a = GPSUtils.parse_gps_string(gps_a)
  local b = GPSUtils.parse_gps_string(gps_b)
  if not a or not b then return false end
  return a.x == b.x and a.y == b.y and a.s == b.s
end

--- Teleport the body (character/vehicle), not the remote-view camera.
---@param player LuaPlayer
---@param position MapPosition
---@param surface LuaSurface
---@return boolean success
---@return string|nil error_code
local function teleport_physical_entity(player, position, surface)
  if player.physical_vehicle and player.physical_vehicle.valid then
    if player.physical_vehicle.speed ~= nil and player.physical_vehicle.speed ~= 0 then
      player.play_sound { path = "utility/cannot_build" }
      return false, "vehicle_moving"
    end
    return player.physical_vehicle.teleport(position, surface, true), nil
  end

  if player.character and player.character.valid then
    local _, physical_surface_index = get_physical_location(player)
    local target_surface_index = surface and surface.valid and surface.index
    local same_surface = physical_surface_index and target_surface_index
        and math.floor(tonumber(physical_surface_index) or 0) == math.floor(tonumber(target_surface_index) or 0)

    if same_surface then
      return player.character.teleport(position, surface, true), nil
    end

    -- Cross-surface: LuaPlayer can hop surfaces; leave remote view first when possible.
    if player.controller_type == defines.controllers.remote then
      pcall(function() player.exit_remote_view() end)
    end
    return player.teleport(position, surface, true), nil
  end

  return player.teleport(position, surface, true), nil
end

---@param player LuaPlayer
---@return boolean, string
local function validate_prerequisites(player)
  if not player.character then
    return false, BasicHelpers.get_error_string(player, "player_character_missing")
  end
  return true, ""
end

--- Get the matching or closest Chart_tag's gps
--- This will return a normalized position gps
---@param player LuaPlayer
---@param gps string
---@return string|nil -- gps string
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
    local surface_index = GPSUtils.get_surface_index_from_gps(gps)
        or GPSUtils.get_context_surface_index(chart_tag, player)
    return GPSUtils.gps_from_map_position(chart_tag.position, surface_index)
  end
  return nil
end

---@param player LuaPlayer Player to teleport
---@param gps string GPS coordinates in 'xxx.yyy.s' format
---@param add_to_history boolean? Whether to add the teleport to history (default true)
---@param action_id string|nil Optional profiling action correlation id
---@return boolean, string -- Final status and GPS string or error code
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

  local target_surface_index = GPSUtils.get_surface_index_from_gps(target_gps)
  local target_surface = resolve_target_surface(target_surface_index, player.surface)
  if not target_surface then
    ErrorHandler.error_log("TeleportStrategy", "Safe teleport failed: Invalid target surface", { target_gps = target_gps }, "teleport_to_gps")
    return false, "invalid_target_surface"
  end

  -- Normalize the pos
  local target_position = GPSUtils.map_position_from_gps(target_gps)
  local physical_position, physical_surface_index = get_physical_location(player)
  local player_gps = nil
  if physical_position and physical_surface_index then
    player_gps = GPSUtils.gps_from_map_position(physical_position, physical_surface_index)
  end
  -- Short-circuit if character is already at the target GPS (not remote-view camera position)
  if player_gps and gps_coords_equal(target_gps, player_gps) then
    ErrorHandler.debug_log("Teleport short-circuited: Already at target GPS", {
      player_gps = player_gps,
      target_gps = target_gps
    })
    return false, "already_at_target"
  end

  -- determine if there is a chart_tag in the immediate vicintiy
  local working_gps = get_closest_chart_tag_gps(player, target_gps)

  -- no matches, find the closest position to our intent
  if not working_gps or working_gps == Constants.settings.BLANK_GPS then
    local search_radius = 4.0
    local precision = 0.5

    -- Use Factorio's built-in collision detection to find a safe position
    ---@type MapPosition|nil
    local safe_target_position = (target_position and type(target_position.x) == "number" and type(target_position.y) == "number") and target_position or {x=0, y=0}
    local non_collide_position = nil
    if safe_target_position and type(safe_target_position.x) == "number" and type(safe_target_position.y) == "number" then
      non_collide_position = target_surface.find_non_colliding_position("character", safe_target_position, search_radius, precision)
    end

    if non_collide_position and type(non_collide_position.x) == "number" and type(non_collide_position.y) == "number" then
      working_gps = GPSUtils.gps_from_map_position(non_collide_position, tonumber(target_surface.index) or 1)
    end
  end

  if not working_gps then
    ErrorHandler.error_log("TeleportStrategy", "Safe teleport failed: No valid safe landing position", {}, "teleport_to_gps")
    BasicHelpers.safe_player_print(player, BasicHelpers.get_error_string(player, "no_safe_landing_position"))
    return false, "no_safe_landing_position"
  end

  -- We have a position - time to teleport
  local working_position = GPSUtils.map_position_from_gps(working_gps)
  if not working_position then
  ErrorHandler.error_log("TeleportStrategy", "Safe teleport failed: Invalid working position", {}, "teleport_to_gps")
  BasicHelpers.safe_player_print(player, BasicHelpers.get_error_string(player, "invalid_working_position"))
    return false, "invalid_working_position"
  end

  local teleport_success, teleport_err = teleport_physical_entity(player, working_position, target_surface)
  if teleport_err == "vehicle_moving" then
    ErrorHandler.warn_log("Safe teleport blocked: Vehicle is moving")
    return false, teleport_err
  end

  if teleport_success then
    -- MULTIPLAYER FIX: render_mode is client-specific and causes desyncs.
    -- Use controller_type which is deterministic game state.
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
  BasicHelpers.safe_player_print(player, BasicHelpers.get_error_string(player, "teleport_failed"))
  return false, "teleport_failed"
end

return TeleportStrategy
