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
local BasicHelpers = require("core.utils.basic_helpers")

local padlen, BLANK_GPS = Constants.settings.GPS_PAD_NUMBER, Constants.settings.BLANK_GPS

---@class GPSUtils
local GPSUtils = {}

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
  local x = math.floor(map_position.x + 0.5)
  local y = math.floor(map_position.y + 0.5)
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
  
  -- Round coordinates and ensure proper padding
  local x = math.floor(map_position.x + 0.5)
  local y = math.floor(map_position.y + 0.5)
  
  -- Use the padding function to ensure at least 3 digits
  return basic_helpers.pad(x, 3) .. "." .. basic_helpers.pad(y, 3)
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

--- Check if a position can be tagged by validating player, chunk charted status, and walkability
---@param player LuaPlayer
---@param map_position MapPosition
---@return boolean can_tag
---@return string? error_message
function GPSUtils.position_can_be_tagged(player, map_position)
  if not BasicHelpers.is_valid_player(player) then
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
  if not player.force.is_chunk_charted(player.surface, chunk) then
    return false, "You are trying to create a tag in uncharted territory"
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

GPSUtils.BLANK_GPS = BLANK_GPS

return GPSUtils
