---@diagnostic disable: undefined-doc-param, param-type-mismatch, missing-parameter, undefined-global

-- core/utils/teleport_strategy.lua
-- TeleportFavorites Factorio Mod
-- Strategy pattern implementation for extensible teleportation logic and scenario handling.

local GPSUtils = require("core.utils.gps_utils")
local ErrorHandler = require("core.utils.error_handler")
local LocaleUtils = require("core.utils.locale_utils")
local ChartTagUtils = require("core.utils.chart_tag_utils")
local PlayerHelpers = require("core.utils.player_helpers")
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
    chart_tag = ChartTagUtils.find_closest_chart_tag_to_position(player, GPSUtils.map_position_from_gps(gps))
  end

  return chart_tag and GPSUtils.gps_from_map_position(chart_tag.position, player.surface.index) or nil
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
    ErrorHandler.debug_log("Teleportation failed: Invalid player")
    return false, "invalid_player"
  end
  if not target_gps or type(target_gps) ~= "string" or target_gps == "" then
    ErrorHandler.debug_log("Teleportation failed: Invalid GPS", { gps = target_gps })
    return false, "invalid_gps"
  end

  local valid, error_msg = validate_prerequisites(player, target_gps)
  if not valid then
    ErrorHandler.debug_log("Safe teleport failed validation", { error = error_msg })
    return false, error_msg
  end

  -- Normalize the pos
  local target_position = GPSUtils.map_position_from_gps(target_gps)
  local player_gps = GPSUtils.gps_from_map_position(player.position, player.surface.index)
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
    local non_collide_position = player.surface.find_non_colliding_position("character", target_position, search_radius,
      precision)

    if not non_collide_position or type(non_collide_position.x) ~= "number" or type(non_collide_position.y) ~= "number" then
      ErrorHandler.debug_log("Safe teleport failed: No valid safe landing position", { position = target_position })
      PlayerHelpers.safe_player_print(player, LocaleUtils.get_error_string(player, "no_safe_landing_position"))
      return false, "no_safe_landing_position"
    end

    working_gps = GPSUtils.gps_from_map_position(non_collide_position)
  end

  if not working_gps then
    ErrorHandler.debug_log("Safe teleport failed: No valid safe landing position", { position = target_position })
    PlayerHelpers.safe_player_print(player, LocaleUtils.get_error_string(player, "no_safe_landing_position"))
    return false, "no_safe_landing_position"
  end

  -- We have a position - time to teleport
  local working_position = GPSUtils.map_position_from_gps(working_gps)
  if not working_position then
    ErrorHandler.debug_log("Safe teleport failed: Invalid working position", { position = working_position })
    PlayerHelpers.safe_player_print(player, LocaleUtils.get_error_string(player, "invalid_working_position"))
    return false, "invalid_working_position"
  end

  local teleport_success = false
  if player.physical_vehicle and player.physical_vehicle.valid then
    if player.physical_vehicle.speed == nil or player.physical_vehicle.speed == 0 then
      teleport_success = player.physical_vehicle.teleport(working_position, player.surface, true)
    else
      player.play_sound { path = "utility/cannot_build" }
      ErrorHandler.debug_log("Safe teleport blocked: Vehicle is moving")
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

  ErrorHandler.debug_log("Safe teleport failed: Unforeseen circumstances")
  return false, "teleport_failed"
end

return TeleportStrategy
