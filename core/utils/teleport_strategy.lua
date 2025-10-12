---@diagnostic disable: undefined-doc-param, param-type-mismatch, missing-parameter, undefined-global

-- core/utils/teleport_strategy.lua
-- TeleportFavorites Factorio Mod
-- Strategy pattern implementation for extensible teleportation logic and scenario handling.

local GPSUtils = require("core.utils.gps_utils")
local ErrorHandler = require("core.utils.error_handler")
local LocaleUtils = require("core.utils.locale_utils")
local ChartTagUtils = require("core.utils.chart_tag_utils")
local BasicHelpers = require("core.utils.basic_helpers")
local Cache = require("core.cache.cache")
local Constants = require("constants")

local TeleportStrategy = {}


---@param player LuaPlayer
---@param gps string
---@return boolean, string
local function validate_prerequisites(player, gps)
  if not player or not player.valid then
    return false, LocaleUtils.get_error_string(player, "player_missing")
  end
  if not player.character then
    return false, LocaleUtils.get_error_string(player, "player_character_missing")
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
  local surface_index = player.surface.index + 0
  return GPSUtils.gps_from_map_position(chart_tag.position, surface_index)
  end
  return nil
end

---@param player LuaPlayer Player to teleport
---@param gps string GPS coordinates in 'xxx.yyy.s' format
---@param add_to_history boolean? Whether to add the teleport to history (default true)
---@return boolean, string -- Final status and GPS string or error code
function TeleportStrategy.teleport_to_gps(player, target_gps, add_to_history)
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

  local valid, error_msg = validate_prerequisites(player, target_gps)
  if not valid then
    ErrorHandler.warn_log("Safe teleport failed validation", { error = error_msg })
    return false, error_msg
  end

  -- Normalize the pos
  local target_position = GPSUtils.map_position_from_gps(target_gps)
  local player_gps = nil
  if player.position and type(player.position.x) == "number" and type(player.position.y) == "number" then
  local surface_index = player.surface.index + 0
  player_gps = GPSUtils.gps_from_map_position(player.position, surface_index)
  end
  -- Short-circuit if player is already at the target GPS position (surface-aware, multiplayer-safe)
  if target_gps == player_gps then
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
      non_collide_position = player.surface.find_non_colliding_position("character", safe_target_position, search_radius, precision)
    end

    if not non_collide_position or type(non_collide_position.x) ~= "number" or type(non_collide_position.y) ~= "number" then
  ErrorHandler.error_log("TeleportStrategy", "Safe teleport failed: No valid safe landing position", {}, "teleport_to_gps")
  BasicHelpers.safe_player_print(player, LocaleUtils.get_error_string(player, "no_safe_landing_position"))
      return false, "no_safe_landing_position"
    end

  working_gps = GPSUtils.gps_from_map_position(non_collide_position, tonumber(player.surface.index) or 1)
  end

  if not working_gps then
  ErrorHandler.error_log("TeleportStrategy", "Safe teleport failed: No valid safe landing position", {}, "teleport_to_gps")
  BasicHelpers.safe_player_print(player, LocaleUtils.get_error_string(player, "no_safe_landing_position"))
    return false, "no_safe_landing_position"
  end

  -- We have a position - time to teleport
  local working_position = GPSUtils.map_position_from_gps(working_gps)
  if not working_position then
  ErrorHandler.error_log("TeleportStrategy", "Safe teleport failed: Invalid working position", {}, "teleport_to_gps")
  BasicHelpers.safe_player_print(player, LocaleUtils.get_error_string(player, "invalid_working_position"))
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
    if player.render_mode ~= defines.render_mode.game then
      player.exit_remote_view()
    end

    if add_to_history then
      local ok, result = pcall(function()
        ErrorHandler.debug_log("[DEBUG] Attempting to add to history", {
          player_index = player.index,
          working_gps = working_gps,
          remote_available = remote.interfaces["TeleportFavorites_History"] ~= nil,
          remote_add_to_history = remote.interfaces["TeleportFavorites_History"] and remote.interfaces["TeleportFavorites_History"].add_to_history ~= nil
        })
        if remote.interfaces["TeleportFavorites_History"] and
            remote.interfaces["TeleportFavorites_History"].add_to_history then
          remote.call("TeleportFavorites_History", "add_to_history", player.index, working_gps)
        end
      end)

      -- TODO remove
      local bebop = 'baloobah'
    end
    return true, working_gps
  end

  ErrorHandler.error_log("TeleportStrategy", "Safe teleport failed: Unforeseen circumstances", {}, "teleport_to_gps")
  return false, "teleport_failed"
end

return TeleportStrategy
