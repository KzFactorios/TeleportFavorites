---@diagnostic disable: unreachable-code
--[[
core/utils/gps_helpers.lua
TeleportFavorites Factorio Mod
-----------------------------
Facade pattern implementation for GPS helper functions.

This file implements the Facade pattern to provide a unified interface to the GPS subsystem:
- gps_core.lua: Basic GPS parsing and validation
- gps_chart_helpers.lua: Chart tag creation and management
- gps_position_normalizer.lua: Complex position normalization

The facade simplifies the complex GPS subsystem and maintains backward compatibility.
]]

-- Import the modular components (subsystems)
local GPSCore = require("core.utils.gps_core")
local GPSChartHelpers = require("core.utils.gps_chart_helpers")
local GPSPositionNormalizer = require("core.utils.gps_position_normalizer")

---@class GPSFacade
---@field core table
---@field chart_helpers table
---@field position_normalizer table
local GPSFacade = {}
GPSFacade.__index = GPSFacade

--- Create GPS facade with subsystem references
---@return GPSFacade
function GPSFacade.create()
  ---@type GPSFacade
  local obj = setmetatable({}, GPSFacade)
  obj.core = GPSCore
  obj.chart_helpers = GPSChartHelpers
  obj.position_normalizer = GPSPositionNormalizer
  return obj
end

--- Unified GPS parsing operation
---@param gps string GPS string to parse
---@return table? parsed_gps Parsed GPS coordinates or nil
function GPSFacade:parse_gps(gps)
  return self.core.parse_gps_string(gps)
end

--- Unified GPS creation operation
---@param position MapPosition Map position
---@param surface_index uint Surface index
---@return string gps GPS string
function GPSFacade:create_gps(position, surface_index)
  return self.core.gps_from_map_position(position, surface_index)
end

--- Unified position normalization operation
---@param player LuaPlayer Player context
---@param gps string Target GPS
---@param Cache table Cache module reference
---@return MapPosition?, table?, LuaCustomChartTag?, table?
function GPSFacade:normalize_position(player, gps, Cache)
  return self.position_normalizer.normalize_landing_position_with_cache(player, gps, Cache)
end

--- Unified chart tag creation operation
---@param player LuaPlayer Player context
---@param spec table Chart tag specification
---@return LuaCustomChartTag?, table result
function GPSFacade:create_chart_tag(player, spec)
  return self.chart_helpers.create_and_validate_chart_tag(player, spec)
end

-- Create singleton facade instance
local gps_facade = GPSFacade.create()

-- Export facade interface with backward compatibility
return {
  -- Constants
  BLANK_GPS = GPSCore.BLANK_GPS,
  
  -- Core GPS functions (delegated through facade)
  parse_gps_string = function(gps) return gps_facade:parse_gps(gps) end,
  gps_from_map_position = function(pos, surf) return gps_facade:create_gps(pos, surf) end,
  map_position_from_gps = GPSCore.map_position_from_gps,
  get_surface_index_from_gps = GPSCore.get_surface_index_from_gps,
  parse_and_normalize_gps = GPSCore.parse_and_normalize_gps,
  
  -- Validation patterns
  ValidationPatterns = GPSCore.ValidationPatterns,
  
  -- Chart helper functions (delegated through facade)
  create_and_validate_chart_tag = function(player, spec) return gps_facade:create_chart_tag(player, spec) end,
  
  -- Position normalization functions (delegated through facade)
  normalize_landing_position = GPSPositionNormalizer.normalize_landing_position,
  normalize_landing_position_with_cache = function(player, gps, Cache) 
    return gps_facade:normalize_position(player, gps, Cache) 
  end,
  
  -- Helper functions for testing/external use
  validate_and_prepare_context = GPSPositionNormalizer.validate_and_prepare_context,
  find_exact_matches = GPSPositionNormalizer.find_exact_matches,
  find_nearby_matches = GPSPositionNormalizer.find_nearby_matches,
  handle_grid_snap_requirements = GPSPositionNormalizer.handle_grid_snap_requirements,
  finalize_position_data = GPSPositionNormalizer.finalize_position_data,
  
  -- Facade access for advanced usage
  facade = gps_facade
}