--[[
core/pattern/teleport_strategy.lua
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

local settings_access = require("core.utils.settings_access")
local gps_helpers = require("core.utils.gps_helpers")
local Cache = require("core.cache.cache")
local ErrorHandler = require("core.utils.error_handler")
local Enum = require("prototypes.enums.enum")
local GameHelpers = require("core.utils.game_helpers")
local LocaleUtils = require("core.utils.locale_utils")

---@class TeleportContext
---@field force_safe boolean? Force safe teleportation mode
---@field precision_mode boolean? Use precise positioning
---@field allow_vehicle boolean? Allow vehicle teleportation
---@field custom_radius number? Custom teleportation radius

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
---@return boolean valid, string error_message
function BaseTeleportStrategy:validate_prerequisites(player, gps)
  if not player or not player.valid then
    return false, LocaleUtils.get_error_string(player, "player_missing")
  end
  
  if rawget(player, "character") == nil then
    return false, LocaleUtils.get_error_string(player, "player_character_missing")
  end
  
  if not gps or gps == "" then
    return false, LocaleUtils.get_error_string(player, "invalid_gps_coordinates")
  end
  
  return true, ""
end

--- Get normalized landing position with caching
---@param player LuaPlayer
---@param gps string
---@return MapPosition? position, string error_message
function BaseTeleportStrategy:get_landing_position(player, gps)
  local _nrm_tag, nrm_chart_tag, _nrm_favorite = gps_helpers.normalize_landing_position_with_cache(player, gps, Cache)
  if not nrm_chart_tag then
    return nil, LocaleUtils.get_error_string(player, "position_normalization_failed")
  end
  return nrm_chart_tag.position, ""
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
  
  local valid, error_msg = self:validate_prerequisites(player, gps)  if not valid then
    ErrorHandler.debug_log("Standard teleport failed validation", { error = error_msg })
    return error_msg or LocaleUtils.get_error_string(player, "validation_failed")
  end
  
  local position, pos_error = self:get_landing_position(player, gps)
  if not position then
    ErrorHandler.debug_log("Standard teleport failed position normalization", { error = pos_error })
    local error_message = pos_error or LocaleUtils.get_error_string(player, "position_normalization_failed")
    GameHelpers.player_print(player, error_message)
    return error_message
  end
    local teleport_success = player:teleport(position, player.surface, true)
  if teleport_success then
    ErrorHandler.debug_log("Standard teleportation successful")
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
  if _G.defines and player.riding_state and player.riding_state ~= _G.defines.riding.acceleration.nothing then
    ErrorHandler.debug_log("Teleport blocked: Player is actively driving")
    GameHelpers.player_print(player, LocaleUtils.get_error_string(player, "driving_teleport_blocked"))
    return LocaleUtils.get_error_string(player, "teleport_blocked_driving")
  end
    local position, pos_error = self:get_landing_position(player, gps)
  if not position then
    ErrorHandler.debug_log("Vehicle teleport failed position normalization", { error = pos_error })
    local error_message = pos_error or LocaleUtils.get_error_string(player, "position_normalization_failed")
    GameHelpers.player_print(player, error_message)
    return error_message
  end
  
  -- Teleport vehicle first, then player
  local vehicle_success = true
  if player.vehicle and player.vehicle.valid then
    vehicle_success = player.vehicle:teleport(position, player.surface, false)
  end
  local player_success = player:teleport(position, player.surface, true)
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
    GameHelpers.player_print(player, error_message)
    return error_message
  end
  
  -- Enhanced safety checks for safe teleportation
  local player_settings = settings_access:getPlayerSettings(player)
  local safety_radius = (context and context.custom_radius) or (player_settings.tp_radius_tiles * 2) -- Double radius for extra safety
    local safe_position = player.surface:find_non_colliding_position("character", position, safety_radius, 0.25)
  if not safe_position then
    ErrorHandler.debug_log("Safe teleport: No safe position found")
    GameHelpers.player_print(player, LocaleUtils.get_error_string(player, "no_safe_position"))
    return LocaleUtils.get_error_string(player, "no_safe_position_available")
  end
  
  -- Use the safer position
  local teleport_success
  if player.driving and player.vehicle and player.vehicle.valid then
    player.vehicle:teleport(safe_position, player.surface, false)
    teleport_success = player:teleport(safe_position, player.surface, true)
  else
    teleport_success = player:teleport(safe_position, player.surface, true)
  end
    if teleport_success then
    ErrorHandler.debug_log("Safe teleportation successful", { safe_position = safe_position })
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
  if not strategy then    ErrorHandler.debug_log("No strategy available for teleportation")
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

-- Initialize strategies when module is loaded
initialize_default_strategies()

-- Export public API
return {
  TeleportStrategyManager = TeleportStrategyManager,
  BaseTeleportStrategy = BaseTeleportStrategy,
  StandardTeleportStrategy = StandardTeleportStrategy,
  VehicleTeleportStrategy = VehicleTeleportStrategy,
  SafeTeleportStrategy = SafeTeleportStrategy
}
