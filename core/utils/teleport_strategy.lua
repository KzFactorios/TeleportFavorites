---@diagnostic disable: undefined-doc-param, param-type-mismatch, missing-parameter
--[[
core/utils/teleport_strategy.lua
TeleportFavorites Factorio Mod
-----------------------------
Strategy Pattern implementation for teleportation logic.

Provides different teleportation strategies for various scenarios:
- Standard teleportation for normal players
- Vehicle teleportation for players in vehicles
- Safe teleportation with enhanced collision detection
- Precision teleportation for exact positioning

This pattern separates teleportation concerns and makes the system extensible
for new teleportation modes without modifying existing code.

STRATEGY PATTERN IMPLEMENTATION:
- BaseTeleportStrategy: Abstract base class defining strategy interface
- Concrete strategies: StandardTeleportStrategy, VehicleTeleportStrategy, SafeTeleportStrategy
- TeleportStrategyManager: Manages strategy selection and execution
- Context-aware strategy selection based on player state and destination

API:
-----
- TeleportStrategyManager.execute_teleport(player, gps, context) -> string|integer
- TeleportStrategyManager.register_strategy(strategy)
- TeleportStrategyManager.get_available_strategies() -> table
]]

local GPSUtils = require("core.utils.gps_utils")
local ErrorHandler = require("core.utils.error_handler")
local Enum = require("prototypes.enums.enum")
local LocaleUtils = require("core.utils.locale_utils")
local PositionUtils = require("core.utils.position_utils")
local ChartTagUtils = require("core.utils.chart_tag_utils")
local PlayerHelpers = require("core.utils.player_helpers")

---@class TeleportContext
---@field force_safe boolean? Force safe teleportation mode
---@field precision_mode boolean? Use precise positioning
---@field allow_vehicle boolean? Allow vehicle teleportation
---@field custom_radius number? Custom teleportation radius


local function find_safe_landing_position(surface, position, radius, precision)
  return PositionUtils.find_safe_landing_position(surface, position, radius, precision)
end

--- Base teleport strategy
---@class BaseTeleportStrategy
local BaseTeleportStrategy = {}
BaseTeleportStrategy.__index = BaseTeleportStrategy

--- Check if this strategy can handle the given teleportation scenario
---@param player LuaPlayer
---@param gps string
---@param context TeleportContext?
---@return boolean can_handle
function BaseTeleportStrategy:can_handle(player, gps, context)
  -- Default implementation - override in concrete strategies
  return false
end

--- Execute the teleportation using this strategy
---@param player LuaPlayer
---@param gps string
---@param context TeleportContext?
---@return string|integer result
function BaseTeleportStrategy:execute(player, gps, context)
  -- Default implementation - override in concrete strategies  ErrorHandler.debug_log("Base strategy execute called - should be overridden")
  return LocaleUtils.get_error_string(nil, "strategy_not_implemented")
end

--- Get the priority of this strategy (higher = more preferred)
---@return number priority
function BaseTeleportStrategy:get_priority()
  return 0
end

--- Get the name of this strategy for logging and debugging
---@return string name
function BaseTeleportStrategy:get_name()
  return "BaseTeleportStrategy"
end

--- Validate common teleportation prerequisites
---@param player LuaPlayer
---@param gps string
---@return boolean valid, string? error_message
function BaseTeleportStrategy:validate_prerequisites(player, gps, context)
  if not player or not player.valid then
    return false, LocaleUtils.get_error_string(player, "player_missing")
  end
  if not player.character then
    return false, LocaleUtils.get_error_string(player, "player_character_missing")
  end
  return true, ""
end

--- Get normalized landing position with caching
---@param player LuaPlayer
---@param gps string
---@return MapPosition? position, string error_message
function BaseTeleportStrategy:get_landing_position(player, gps)
  -- Simple approach: get position from GPS and validate
  local position = GPSUtils.map_position_from_gps(gps)
  if not position then
    return nil, LocaleUtils.get_error_string(player, "invalid_gps_format")
  end

  -- If a chart tag exists within the positions chart_tag_radius
  -- then we will use the position of that chart_tag
  local chart_tag = ChartTagUtils.find_closest_chart_tag_to_position(player, position)
  if chart_tag then
    return chart_tag.position, ""
  end

  return position, ""
end

--- Standard Teleportation Strategy
---@class StandardTeleportStrategy : BaseTeleportStrategy
local StandardTeleportStrategy = {}
StandardTeleportStrategy.__index = StandardTeleportStrategy
setmetatable(StandardTeleportStrategy, { __index = BaseTeleportStrategy })

function StandardTeleportStrategy:new()
  local obj = setmetatable({}, self)
  return obj
end

function StandardTeleportStrategy:can_handle(player, gps, context)
  -- Handle standard teleportation when player is not in vehicle
  return not (player.driving and player.vehicle)
end

function StandardTeleportStrategy:execute(player, gps, context)
  ErrorHandler.debug_log("Executing standard teleportation", {
    player_name = player.name,
    gps = gps,
    strategy = self:get_name()
  })

  local valid, error_msg = self:validate_prerequisites(player, gps)
  if not valid then
    ErrorHandler.debug_log("Standard teleport failed validation", { error = error_msg })
    return error_msg or LocaleUtils.get_error_string(player, "validation_failed")
  end
  local position, pos_error = self:get_landing_position(player, gps)
  if not position then
    ErrorHandler.debug_log("Standard teleport failed position normalization", { error = pos_error })
    local error_message = pos_error or LocaleUtils.get_error_string(player, "position_normalization_failed")
    PlayerHelpers.safe_player_print(player, error_message)
    return error_message
  end
  -- Always find the safest landing position regardless of tile type
  local final_position = position
  local safe_position = PositionUtils.find_safe_landing_position(player.surface, position, 16.0, 0.5)
  if safe_position then
    final_position = safe_position
    ErrorHandler.debug_log("Using optimized landing position", {
      original = position,
      safe = safe_position
    })
  end

  -- Execute teleport and verify success
  local teleport_success = player.teleport(final_position, player.surface, true)
  if teleport_success then
    ErrorHandler.debug_log("Standard teleport successful", { final_position = final_position })
    return Enum.ReturnStateEnum.SUCCESS
  end

  ErrorHandler.debug_log("Standard teleport failed: Unforeseen circumstances")
  return LocaleUtils.get_error_string(player, "teleport_unforeseen_error")
end

function StandardTeleportStrategy:get_priority()
  return 1 -- Base priority for standard teleportation
end

function StandardTeleportStrategy:get_name()
  return "StandardTeleportStrategy"
end

--- Vehicle Teleportation Strategy
---@class VehicleTeleportStrategy : BaseTeleportStrategy
local VehicleTeleportStrategy = {}
VehicleTeleportStrategy.__index = VehicleTeleportStrategy
setmetatable(VehicleTeleportStrategy, { __index = BaseTeleportStrategy })

function VehicleTeleportStrategy:new()
  local obj = setmetatable({}, self)
  return obj
end

function VehicleTeleportStrategy:can_handle(player, gps, context)
  -- Handle teleportation when player is in a vehicle
  if not (player.driving and player.vehicle) then
    return false
  end

  -- Check if vehicle teleportation is explicitly disabled
  if context and context.allow_vehicle == false then
    return false
  end

  return true
end

function VehicleTeleportStrategy:execute(player, gps, context)
  ErrorHandler.debug_log("Executing vehicle teleportation", {
    player_name = player.name,
    gps = gps,
    vehicle_name = player.vehicle and player.vehicle.name,
    strategy = self:get_name()
  })
  local valid, error_msg = self:validate_prerequisites(player, gps)
  if not valid then
    ErrorHandler.debug_log("Vehicle teleport failed validation", { error = error_msg })
    return error_msg or LocaleUtils.get_error_string(player, "validation_failed")
  end
  -- Check if player is actively driving (not just a passenger)
  if defines and player.riding_state and player.riding_state ~= defines.riding.acceleration.nothing then
    ErrorHandler.debug_log("Teleport blocked: Player is actively driving")
    PlayerHelpers.safe_player_print(player, LocaleUtils.get_error_string(player, "driving_teleport_blocked"))
    return LocaleUtils.get_error_string(player, "teleport_blocked_driving")
  end
  local position, pos_error = self:get_landing_position(player, gps)
  if not position then
    ErrorHandler.debug_log("Vehicle teleport failed position normalization", { error = pos_error })
    local error_message = pos_error or LocaleUtils.get_error_string(player, "position_normalization_failed")
    PlayerHelpers.safe_player_print(player, error_message)
    return error_message
  end
  -- Always find the safest landing position regardless of tile type
  local final_position = position
  local safe_position = find_safe_landing_position(player.surface, position, 16.0, 0.5)
  if safe_position then
    final_position = safe_position
    ErrorHandler.debug_log("Using optimized vehicle landing position", {
      original = position,
      safe = safe_position
    })
  end

  -- Teleport vehicle first, then player
  local vehicle_success = true
  if player.vehicle and player.vehicle.valid then
    vehicle_success = player.vehicle:teleport(final_position, player.surface, false)
  end
  local player_success = player.teleport(final_position, player.surface, true)
  if vehicle_success and player_success then
    ErrorHandler.debug_log("Vehicle teleportation successful")
    return Enum.ReturnStateEnum.SUCCESS
  end

  ErrorHandler.debug_log("Vehicle teleport failed", {
    vehicle_success = vehicle_success,
    player_success = player_success
  })
  return LocaleUtils.get_error_string(player, "vehicle_teleport_unforeseen_error")
end

function VehicleTeleportStrategy:get_priority()
  return 2 -- Higher priority than standard when in vehicle
end

function VehicleTeleportStrategy:get_name()
  return "VehicleTeleportStrategy"
end

--- Safe Teleportation Strategy
---@class SafeTeleportStrategy : BaseTeleportStrategy
local SafeTeleportStrategy = {}
SafeTeleportStrategy.__index = SafeTeleportStrategy
setmetatable(SafeTeleportStrategy, { __index = BaseTeleportStrategy })

function SafeTeleportStrategy:new()
  local obj = setmetatable({}, self)
  return obj
end

function SafeTeleportStrategy:can_handle(player, gps, context)
  -- Handle safe teleportation when explicitly requested
  if context and context.force_safe == true then
    return true
  end
  return false
end

function SafeTeleportStrategy:execute(player, gps, context)
  ErrorHandler.debug_log("Executing safe teleportation", {
    player_name = player.name,
    gps = gps,
    strategy = self:get_name()
  })
  local valid, error_msg = self:validate_prerequisites(player, gps)
  if not valid then
    ErrorHandler.debug_log("Safe teleport failed validation", { error = error_msg })
    return error_msg or LocaleUtils.get_error_string(player, "validation_failed")
  end

  local position, pos_error = self:get_landing_position(player, gps)
  if not position then
    ErrorHandler.debug_log("Safe teleport failed position normalization", { error = pos_error })
    local error_message = pos_error or LocaleUtils.get_error_string(player, "position_normalization_failed")
    PlayerHelpers.safe_player_print(player, error_message)
    return error_message
  end
  
  -- Keep it simple. Just teleport to a position close to our position
  -- Default safety radius for finding safe positions
  local safety_radius = (context and context.custom_radius) or 16.0 

  -- Always find the safest landing position
  local final_position = position
  local safe_position = find_safe_landing_position(player.surface, position, safety_radius, 0.5)
  if safe_position then
    final_position = safe_position
    ErrorHandler.debug_log("Using optimized safe landing position", {
      original = position,
      safe = safe_position
    })
  end

  local teleport_success = false
  -- Use the final position (either original or safe landing spot)
  local teleport_success
  if player.driving and player.vehicle and player.vehicle.valid then
    player.vehicle:teleport(final_position, player.surface, false)
    teleport_success = player.teleport(final_position, player.surface, true)
  else
    teleport_success = player.teleport(final_position, player.surface, true)
  end
  if teleport_success then
    ErrorHandler.debug_log("Safe teleportation successful", { final_position = final_position })
    return Enum.ReturnStateEnum.SUCCESS
  end

  ErrorHandler.debug_log("Safe teleport failed: Unforeseen circumstances")
  return LocaleUtils.get_error_string(player, "safe_teleport_unforeseen_error")
end

function SafeTeleportStrategy:get_priority()
  return 10 -- Highest priority when safe mode is requested
end

function SafeTeleportStrategy:get_name()
  return "SafeTeleportStrategy"
end

--- Teleport Strategy Manager
---@class TeleportStrategyManager
local TeleportStrategyManager = {
  strategies = {}
}

--- Register a new teleportation strategy
---@param strategy table
function TeleportStrategyManager.register_strategy(strategy)
  if not strategy or type(strategy.can_handle) ~= "function" or type(strategy.execute) ~= "function" then
    ErrorHandler.debug_log("Invalid strategy registration attempt", {
      strategy_name = strategy and strategy.get_name and strategy:get_name() or "unknown"
    })
    return
  end

  table.insert(TeleportStrategyManager.strategies, strategy)
  ErrorHandler.debug_log("Strategy registered", { strategy_name = strategy:get_name() })
end

--- Find the best strategy for the given scenario
---@param player LuaPlayer
---@param gps string
---@param context TeleportContext?
---@return table? strategy
function TeleportStrategyManager.find_best_strategy(player, gps, context)
  local available_strategies = {}

  -- Collect all strategies that can handle this scenario
  for _, strategy in ipairs(TeleportStrategyManager.strategies) do
    if strategy:can_handle(player, gps, context) then
      table.insert(available_strategies, strategy)
    end
  end

  if #available_strategies == 0 then
    ErrorHandler.debug_log("No suitable strategy found", {
      player_name = player and player.name,
      gps = gps,
      context = context
    })
    return nil
  end

  -- Sort by priority (highest first)
  table.sort(available_strategies, function(a, b)
    return a:get_priority() > b:get_priority()
  end)

  local selected_strategy = available_strategies[1]
  ErrorHandler.debug_log("Strategy selected", {
    strategy_name = selected_strategy:get_name(),
    priority = selected_strategy:get_priority(),
    alternatives = #available_strategies - 1
  })

  return selected_strategy
end

--- Execute teleportation using the best available strategy
---@param player LuaPlayer
---@param gps string
---@param context TeleportContext?
---@return string|integer result
function TeleportStrategyManager.execute_teleport(player, gps, context)
  ErrorHandler.debug_log("Starting strategy-based teleportation", {
    player_name = player and player.name,
    gps = gps,
    context = context,
    available_strategies = #TeleportStrategyManager.strategies
  })

  local strategy = TeleportStrategyManager.find_best_strategy(player, gps, context)
  if not strategy then
    ErrorHandler.debug_log("No strategy available for teleportation")
    return LocaleUtils.get_error_string(player, "no_suitable_strategy")
  end

  local result = strategy:execute(player, gps, context)
  ErrorHandler.debug_log("Strategy execution completed", {
    strategy_name = strategy:get_name(),
    result = result
  })

  return result
end

--- Get list of all available strategies
---@return table[] strategies
function TeleportStrategyManager.get_available_strategies()
  return TeleportStrategyManager.strategies
end

--- Initialize default strategies
local function initialize_default_strategies()
  TeleportStrategyManager.register_strategy(StandardTeleportStrategy:new())
  TeleportStrategyManager.register_strategy(VehicleTeleportStrategy:new())
  TeleportStrategyManager.register_strategy(SafeTeleportStrategy:new())

  ErrorHandler.debug_log("Default teleportation strategies initialized", {
    strategy_count = #TeleportStrategyManager.strategies
  })
end

-- ====== TELEPORT UTILS MODULE (consolidated from teleport_utils.lua) ======
-- Shared teleportation logic wrapper for high-level API

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
  local result = TeleportStrategyManager.execute_teleport(player, gps, context)
  if return_raw then
    if type(result) == "string" or type(result) == "number" then
      return result
    else
      return "teleport_failed"
    end
  else
    if result == Enum.ReturnStateEnum.SUCCESS then
      -- Notify teleport history via remote interface
      pcall(function()
        if remote.interfaces["TeleportFavorites_History"] and 
           remote.interfaces["TeleportFavorites_History"].add_to_history then
          remote.call("TeleportFavorites_History", "add_to_history", player.index)
        end
      end)
      return true
    else
      return false
    end
  end
end

-- Initialize strategies when module is loaded
initialize_default_strategies()

-- Export public API
return {
  TeleportStrategyManager = TeleportStrategyManager,
  BaseTeleportStrategy = BaseTeleportStrategy,
  StandardTeleportStrategy = StandardTeleportStrategy,
  VehicleTeleportStrategy = VehicleTeleportStrategy,
  SafeTeleportStrategy = SafeTeleportStrategy,
  TeleportUtils = TeleportUtils
}
