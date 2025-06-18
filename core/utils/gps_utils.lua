---@diagnostic disable: undefined-global
--[[
core/utils/gps_utils.lua
TeleportFavorites Factorio Mod
-----------------------------
Consolidated GPS utilities combining all GPS-related functionality.

This module consolidates:
- gps_parser.lua - Basic GPS string parsing and validation
- gps_core.lua - Core GPS utilities and validation patterns  
- gps_helpers.lua - GPS facade and helper functions
- gps_chart_helpers.lua - Chart tag creation and validation
- gps_position_normalizer.lua - Position normalization with GPS integration

Provides a unified API for all GPS-related operations throughout the mod.
]]

local basic_helpers = require("core.utils.basic_helpers")
local Constants = require("constants")
local ErrorHandler = require("core.utils.error_handler")

local padlen, BLANK_GPS = Constants.settings.GPS_PAD_NUMBER, Constants.settings.BLANK_GPS

---@class GPSUtils
local GPSUtils = {}

-- ========================================
-- CORE GPS PARSING
-- ========================================

--- Parse a GPS string 'x.y.s' into {x, y, surface_index} or nil if invalid
---@param gps string
---@return table|nil
function GPSUtils.parse_gps_string(gps)
  if type(gps) ~= "string" then return nil end
  if gps == BLANK_GPS then return { x = 0, y = 0, s = -1 } end

  local x, y, s = gps:match("^(%-?%d+)%.(%-?%d+)%.(%d+)$")
  if not x or not y or not s then return nil end
  local parsed_x, parsed_y, parsed_s = tonumber(x), tonumber(y), tonumber(s)
  
  if not parsed_x or not parsed_y or not parsed_s then return nil end
  return { x = parsed_x, y = parsed_y, s = parsed_s }
end

--- Convert a map position to a GPS string
---@param map_position MapPosition Table with x and y coordinates
---@param surface_index number Surface index (defaults to 1)
---@return string GPS string in format 'x.y.s'
function GPSUtils.gps_from_map_position(map_position, surface_index)
  if not map_position or type(map_position.x) ~= "number" or type(map_position.y) ~= "number" then
    return tostring(BLANK_GPS)
  end
  
  surface_index = surface_index or 1
  local x = basic_helpers.normalize_index(map_position.x)
  local y = basic_helpers.normalize_index(map_position.y)
  
  return basic_helpers.pad(x, padlen) .. "." .. basic_helpers.pad(y, padlen) .. "." .. tostring(surface_index)
end

--- Convert a GPS string to a map position
---@param gps string GPS string in format 'x.y.s'
---@return MapPosition? map_position Table with x and y coordinates, or nil if invalid
function GPSUtils.map_position_from_gps(gps)
  local parsed = GPSUtils.parse_gps_string(gps)
  if not parsed then return nil end
  return { x = parsed.x, y = parsed.y }
end

--- Get surface index from GPS string
---@param gps string GPS string in format 'x.y.s'
---@return number? surface_index Surface index, or nil if invalid
function GPSUtils.get_surface_index_from_gps(gps)
  local parsed = GPSUtils.parse_gps_string(gps)
  if not parsed then return nil end
  return parsed.s
end

--- Parse and normalize a GPS string to ensure consistent format
---@param gps string Input GPS string
---@return string normalized_gps Normalized GPS string
function GPSUtils.parse_and_normalize_gps(gps)
  local parsed = GPSUtils.parse_gps_string(gps)
  if not parsed then return tostring(BLANK_GPS) end
  
  return GPSUtils.gps_from_map_position({ x = parsed.x, y = parsed.y }, parsed.s)
end

--- Get coordinate string from GPS (x.y format without surface)
---@param gps string GPS string
---@return string? coords_string Coordinate string in format 'x.y', or nil if invalid
function GPSUtils.coords_string_from_gps(gps)
  local parsed = GPSUtils.parse_gps_string(gps)
  if not parsed then return nil end
  
  return basic_helpers.pad(parsed.x, padlen) .. "." .. basic_helpers.pad(parsed.y, padlen)
end

--- Get coordinate string from map position (x.y format without surface)
---@param map_position MapPosition
---@return string coords_string Coordinate string in format 'x.y'
function GPSUtils.coords_string_from_map_position(map_position)
  if not map_position or type(map_position.x) ~= "number" or type(map_position.y) ~= "number" then
    return "0.0"
  end
  
  local x = basic_helpers.normalize_index(map_position.x)
  local y = basic_helpers.normalize_index(map_position.y)
  
  return basic_helpers.pad(x, padlen) .. "." .. basic_helpers.pad(y, padlen)
end

-- ========================================
-- GPS VALIDATION PATTERNS
-- ========================================

--- Standardized way to check if a tag is valid and usable
---@param tag table?
---@return boolean
function GPSUtils.is_valid_tag(tag)
  if not tag then return false end
  if type(tag.gps) ~= "string" or tag.gps == "" or tag.gps == BLANK_GPS then return false end
  return true
end

--- Standardized way to check if a chart tag is valid
---@param chart_tag LuaCustomChartTag?
---@return boolean
function GPSUtils.is_valid_chart_tag(chart_tag)
  if not chart_tag or not chart_tag.valid then return false end
  if not chart_tag.position or type(chart_tag.position.x) ~= "number" or type(chart_tag.position.y) ~= "number" then return false end
  return true
end

--- Validate GPS string format
---@param gps string
---@return boolean is_valid
---@return string? error_message
function GPSUtils.validate_gps_format(gps)
  if type(gps) ~= "string" then
    return false, "GPS must be a string"
  end
    if gps == BLANK_GPS then
    -- Blank GPS is considered valid
    return true
  end
  
  local parsed = GPSUtils.parse_gps_string(gps)
  if not parsed then
    return false, "Invalid GPS format. Expected 'x.y.s' where x, y are integers and s is surface index"
  end
  
  if parsed.s < 0 then
    return false, "Invalid surface index. Must be non-negative"
  end
  
  return true
end

--- Validate map position for GPS conversion
---@param map_position MapPosition
---@return boolean is_valid
---@return string? error_message
function GPSUtils.validate_map_position(map_position)
  if type(map_position) ~= "table" then
    return false, "Position must be a table"
  end
  
  if type(map_position.x) ~= "number" then
    return false, "Position.x must be a number"
  end
  
  if type(map_position.y) ~= "number" then
    return false, "Position.y must be a number"
  end
    -- Check for reasonable coordinate bounds (Factorio world limits)
  -- Factorio's practical world limit
  local max_coord = 2000000
  if math.abs(map_position.x) > max_coord or math.abs(map_position.y) > max_coord then
    return false, "Position coordinates are outside reasonable world bounds"
  end
  
  return true
end

-- ========================================
-- CHART TAG HELPERS
-- ========================================

--- Check if a position can be tagged by validating player, chunk charted status, and walkability
---@param player LuaPlayer
---@param map_position MapPosition
---@return boolean can_tag
---@return string? error_message
function GPSUtils.position_can_be_tagged(player, map_position)
  if not player or not player.valid then
    return false, "Invalid player"
  end
  
  if not player.surface or not player.surface.valid then
    return false, "Invalid surface"
  end
  
  -- Validate position format
  local pos_valid, pos_error = GPSUtils.validate_map_position(map_position)
  if not pos_valid then
    return false, pos_error
  end
    -- Check if the chunk is charted
  local chunk = { x = math.floor(map_position.x / 32), y = math.floor(map_position.y / 32) }
  if not player.force:is_chunk_charted(player.surface, chunk) then
    return false, "You are trying to create a tag in uncharted territory"
  end
  
  -- Check for water/space tiles using basic tile checking
  -- Note: This is simplified - full terrain validation should use PositionUtils
  local tile = player.surface:get_tile(map_position.x, map_position.y)
  if tile and tile.valid then
    local tile_name = tile.name:lower()
    if tile_name:find("water") or tile_name:find("space") or tile_name:find("void") then
      return false, "You cannot tag water or space locations"
    end
  end
  
  return true
end

--- Create a chart tag specification for Factorio's API
---@param player LuaPlayer
---@param map_position MapPosition
---@param text string Tag text
---@param icon SignalID? Optional icon
---@param set_ownership boolean? Whether to set last_user (only for final tags, not temporary)
---@return table? chart_tag_spec Chart tag specification or nil if invalid
function GPSUtils.create_chart_tag_spec(player, map_position, text, icon, set_ownership)
  local can_tag, error_msg = GPSUtils.position_can_be_tagged(player, map_position)
  if not can_tag then
    ErrorHandler.warn_log("Cannot create chart tag: " .. (error_msg or "Unknown error"))
    return nil
  end
    local spec = {
    position = map_position,
    text = text or ""
  }
  
  -- Only set last_user if this is a final chart tag (not temporary)
  if set_ownership then
    spec.last_user = player.name
  end
    if icon and icon.name then
    spec.icon = icon
  end
  
  return spec
end

--- Create and validate a chart tag using Factorio's API
---@param player LuaPlayer
---@param map_position MapPosition  
---@param text string Tag text
---@param icon SignalID? Optional icon
---@return LuaCustomChartTag? chart_tag Created chart tag or nil if failed
function GPSUtils.create_and_validate_chart_tag(player, map_position, text, icon)
  -- Use set_ownership=false since this is for temporary validation
  local spec = GPSUtils.create_chart_tag_spec(player, map_position, text, icon, false)
  if not spec then return nil end
  
  -- Try to create the chart tag
  local success, result = pcall(function()
    return player.force.add_chart_tag(player.surface, spec)
  end)
  
  if not success then
    ErrorHandler.warn_log("Failed to create chart tag: " .. tostring(result))
    return nil
  end
  
  if not result or type(result) ~= "table" or not result.valid then
    ErrorHandler.warn_log("Failed to create chart tag at position: " .. 
      GPSUtils.coords_string_from_map_position(map_position))
    return nil
  end
  
  return result
end

-- ========================================
-- POSITION NORMALIZATION WITH GPS
-- ========================================

--- Normalize a position and update associated GPS data
---@param map_position MapPosition
---@param surface_index number
---@return MapPosition normalized_position
---@return string normalized_gps
function GPSUtils.normalize_position_with_gps(map_position, surface_index)
  local normalized_pos = {
    x = tonumber(basic_helpers.normalize_index(map_position.x)) or 0,
    y = tonumber(basic_helpers.normalize_index(map_position.y)) or 0
  }
  
  local normalized_gps = GPSUtils.gps_from_map_position(normalized_pos, surface_index)
  
  return normalized_pos, normalized_gps
end

--- Check if a GPS string needs normalization
---@param gps string
---@return boolean needs_normalization
function GPSUtils.gps_needs_normalization(gps)
  local position = GPSUtils.map_position_from_gps(gps)
  if not position then return false end
  
  -- Check if coordinates are whole numbers
  return position.x ~= math.floor(position.x) or position.y ~= math.floor(position.y)
end

--- Get normalized and original GPS for position tracking
---@param gps string
---@return table {old_gps: string, new_gps: string, old_position: MapPosition, new_position: MapPosition}
function GPSUtils.get_gps_normalization_data(gps)
  local position = GPSUtils.map_position_from_gps(gps)
  if not position then
    return {
      old_gps = gps,
      new_gps = gps,
      old_position = {x = 0, y = 0},
      new_position = {x = 0, y = 0}
    }
  end
  
  local surface_index = GPSUtils.get_surface_index_from_gps(gps) or 1
  local normalized_pos, normalized_gps = GPSUtils.normalize_position_with_gps(position, surface_index)
  
  return {
    old_gps = gps,
    new_gps = normalized_gps,
    old_position = position,
    new_position = normalized_pos
  }
end

-- ========================================
-- CONSTANTS AND EXPORTS
-- ========================================

GPSUtils.BLANK_GPS = BLANK_GPS

return GPSUtils
