---@diagnostic disable: unreachable-code
--[[
core/utils/gps_helpers.lua
TeleportFavorites Factorio Mod
-----------------------------
Legacy facade for GPS helper functions.

This file has been refactored into smaller, focused modules:
- gps_core.lua: Basic GPS parsing and validation
- gps_chart_helpers.lua: Chart tag creation and management
- gps_position_normalizer.lua: Complex position normalization

All original functions are maintained for backward compatibility.
]]

-- Import the modular components
local GPSCore = require("core.utils.gps_core")
local GPSChartHelpers = require("core.utils.gps_chart_helpers")
local GPSPositionNormalizer = require("core.utils.gps_position_normalizer")

-- Export all functions from the modules to maintain backward compatibility
return {
  -- Constants
  BLANK_GPS = GPSCore.BLANK_GPS,
  
  -- Core GPS functions
  parse_gps_string = GPSCore.parse_gps_string,
  gps_from_map_position = GPSCore.gps_from_map_position,
  map_position_from_gps = GPSCore.map_position_from_gps,
  get_surface_index_from_gps = GPSCore.get_surface_index_from_gps,
  parse_and_normalize_gps = GPSCore.parse_and_normalize_gps,
  
  -- Validation patterns
  ValidationPatterns = GPSCore.ValidationPatterns,
  
  -- Chart helper functions
  create_and_validate_chart_tag = GPSChartHelpers.create_and_validate_chart_tag,
  
  -- Position normalization functions
  normalize_landing_position = GPSPositionNormalizer.normalize_landing_position,
  normalize_landing_position_with_cache = GPSPositionNormalizer.normalize_landing_position_with_cache,
  
  -- Helper functions for testing/external use
  validate_and_prepare_context = GPSPositionNormalizer.validate_and_prepare_context,
  find_exact_matches = GPSPositionNormalizer.find_exact_matches,
  find_nearby_matches = GPSPositionNormalizer.find_nearby_matches,
  handle_grid_snap_requirements = GPSPositionNormalizer.handle_grid_snap_requirements,
  finalize_position_data = GPSPositionNormalizer.finalize_position_data
}