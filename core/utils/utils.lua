---@diagnostic disable: undefined-global
--[[
core/utils/utils.lua
TeleportFavorites Factorio Mod
-----------------------------
Unified utilities facade providing single entry point to all utility functions.

This module consolidates and provides access to:
- position_utils.lua - Position, terrain, and validation utilities
- gps_utils.lua - GPS parsing, conversion, and chart tag utilities
- collection_utils.lua - Data manipulation and functional programming utilities
- Core utilities (basic_helpers, error_handler, settings_access)

Usage:
  local Utils = require("core.utils.utils")
  Utils.position.normalize_position(pos)
  Utils.gps.parse_gps_string(gps_str)
  Utils.collection.map(table, mapper_func)
  Utils.handle_error(player, message)

Provides both unified access and backward compatibility for existing code.
]]

-- Import consolidated utility modules
local PositionUtils = require("core.utils.position_utils")
local GPSUtils = require("core.utils.gps_utils")
local CollectionUtils = require("core.utils.collection_utils")

-- Import core utilities
local basic_helpers = require("core.utils.basic_helpers")
local ErrorHandler = require("core.utils.error_handler")
local SettingsAccess = require("core.utils.settings_access")

---@class Utils
local Utils = {}

-- ========================================
-- DOMAIN-SPECIFIC UTILITIES
-- ========================================

--- Position and terrain utilities
Utils.position = PositionUtils

--- GPS and chart tag utilities
Utils.gps = GPSUtils

--- Collection and data manipulation utilities
Utils.collection = CollectionUtils

-- ========================================
-- CORE UTILITIES (Direct Access)
-- ========================================

--- Error handling utilities
Utils.error = ErrorHandler
Utils.handle_error = ErrorHandler.handle_error
Utils.success = ErrorHandler.success
Utils.failure = ErrorHandler.failure
Utils.warn_log = ErrorHandler.warn_log
Utils.debug_log = ErrorHandler.debug_log

--- Basic helper functions
Utils.pad = basic_helpers.pad
Utils.is_whole_number = basic_helpers.is_whole_number
Utils.trim = basic_helpers.trim
Utils.normalize_index = basic_helpers.normalize_index

--- Settings access
Utils.settings = SettingsAccess
Utils.get_player_settings = SettingsAccess.getPlayerSettings

-- ========================================
-- CONVENIENCE ALIASES (Commonly Used Functions)
-- ========================================

--- Position utilities (frequently used)
Utils.normalize_position = PositionUtils.normalize_position
Utils.is_walkable_position = PositionUtils.is_walkable_position
Utils.is_water_tile = PositionUtils.is_water_tile
Utils.is_space_tile = PositionUtils.is_space_tile
Utils.find_valid_position = PositionUtils.find_valid_position
Utils.position_can_be_tagged = PositionUtils.position_can_be_tagged

--- GPS utilities (frequently used)
Utils.parse_gps_string = GPSUtils.parse_gps_string
Utils.gps_from_map_position = GPSUtils.gps_from_map_position
Utils.map_position_from_gps = GPSUtils.map_position_from_gps
Utils.get_surface_index_from_gps = GPSUtils.get_surface_index_from_gps
Utils.create_chart_tag_spec = GPSUtils.create_chart_tag_spec
Utils.validate_gps_format = GPSUtils.validate_gps_format

--- Collection utilities (frequently used)
Utils.map = CollectionUtils.map
Utils.filter = CollectionUtils.filter
Utils.for_each = CollectionUtils.for_each
Utils.deep_copy = CollectionUtils.deep_copy
Utils.shallow_copy = CollectionUtils.shallow_copy
Utils.table_find = CollectionUtils.table_find
Utils.table_count = CollectionUtils.table_count
Utils.find_first_match = CollectionUtils.find_first_match

-- ========================================
-- BACKWARD COMPATIBILITY LAYER
-- ========================================

--- Legacy helpers_suite.lua compatibility
--- These aliases ensure existing code continues to work
Utils.tables_equal = CollectionUtils.tables_equal
Utils.remove_first = CollectionUtils.remove_first
Utils.table_is_empty = CollectionUtils.table_is_empty
Utils.create_empty_indexed_array = CollectionUtils.create_empty_indexed_array
Utils.array_sort_by_index = CollectionUtils.array_sort_by_index
Utils.index_is_in_table = CollectionUtils.index_is_in_table
Utils.find_by_predicate = CollectionUtils.find_by_predicate
Utils.table_remove_value = CollectionUtils.table_remove_value
Utils.process_until_match = CollectionUtils.process_until_match
Utils.reduce = CollectionUtils.reduce
Utils.partition = CollectionUtils.partition
Utils.math_round = CollectionUtils.math_round

--- Legacy terrain_validator.lua compatibility
-- Full terrain module access
Utils.terrain = PositionUtils
Utils.find_nearest_walkable_position = PositionUtils.find_nearest_walkable_position
Utils.find_valid_position_in_box = PositionUtils.find_valid_position_in_box

--- Legacy position_validator.lua compatibility
Utils.is_valid_tag_position = PositionUtils.is_valid_tag_position
Utils.print_teleport_event_message = PositionUtils.print_teleport_event_message

--- Legacy position_normalizer.lua compatibility
Utils.needs_normalization = PositionUtils.needs_normalization
Utils.create_position_pair = PositionUtils.create_position_pair
Utils.normalize_if_needed = PositionUtils.normalize_if_needed

--- Legacy GPS modules compatibility
Utils.coords_string_from_gps = GPSUtils.coords_string_from_gps
Utils.coords_string_from_map_position = GPSUtils.coords_string_from_map_position
Utils.parse_and_normalize_gps = GPSUtils.parse_and_normalize_gps
Utils.is_valid_tag = GPSUtils.is_valid_tag
Utils.is_valid_chart_tag = GPSUtils.is_valid_chart_tag
Utils.validate_map_position = GPSUtils.validate_map_position
Utils.create_and_validate_chart_tag = GPSUtils.create_and_validate_chart_tag
Utils.normalize_position_with_gps = GPSUtils.normalize_position_with_gps
Utils.gps_needs_normalization = GPSUtils.gps_needs_normalization
Utils.get_gps_normalization_data = GPSUtils.get_gps_normalization_data
Utils.BLANK_GPS = GPSUtils.BLANK_GPS
-- GPS core utilities
local GPSCore = require("core.utils.gps_utils")
Utils.ValidationPatterns = GPSCore.ValidationPatterns

-- ========================================
-- UTILITY INFORMATION
-- ========================================

--- Get information about available utility modules
---@return table module_info
function Utils.get_module_info()
  return {
    domains = {
      position = "Position, terrain, and validation utilities",
      gps = "GPS parsing, conversion, and chart tag utilities", 
      collection = "Data manipulation and functional programming utilities",
      error = "Error handling and reporting utilities",
      settings = "Settings access utilities"
    },
    consolidated_modules = {
      "position_utils.lua - Position/terrain operations",
      "gps_utils.lua - GPS and chart tag operations", 
      "collection_utils.lua - Data structure operations"
    },
    backward_compatibility = "Full compatibility with legacy helper modules maintained"
  }
end

--- List all available utility functions
---@return table function_list
function Utils.list_functions()
  local functions = {}
  
  -- Collect all functions from the Utils table
  for name, func in pairs(Utils) do
    if type(func) == "function" then
      table.insert(functions, name)
    end
  end
  
  -- Sort alphabetically for easier browsing
  table.sort(functions)
  
  return functions
end

return Utils
