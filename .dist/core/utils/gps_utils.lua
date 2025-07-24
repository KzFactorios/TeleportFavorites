local BasicHelpers = require("core.utils.basic_helpers")
local Constants = require("constants")

local padlen, BLANK_GPS = Constants.settings.GPS_PAD_NUMBER, Constants.settings.BLANK_GPS

---@class GPSUtils
local GPSUtils = {}

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
  return BasicHelpers.pad(x, padlen) .. "." .. BasicHelpers.pad(y, padlen) .. "." .. tostring(surface_index)
end

---@param gps string GPS string in format 'x.y.s'
---@return MapPosition? map_position Table with x and y coordinates, or nil if invalid
function GPSUtils.map_position_from_gps(gps)
  local parsed = GPSUtils.parse_gps_string(gps)
  if not parsed then return nil end
  return { x = parsed.x, y = parsed.y }
end

---@param gps string GPS string in format 'x.y.s'
---@return number? surface_index Surface index, or nil if invalid
function GPSUtils.get_surface_index_from_gps(gps)
  local parsed = GPSUtils.parse_gps_string(gps)
  if not parsed then return nil end
  return parsed.s
end

---@param gps string GPS string
---@return string? coords_string Coordinate string in format 'x.y', or nil if invalid
function GPSUtils.coords_string_from_gps(gps)
  local parsed = GPSUtils.parse_gps_string(gps)
  if not parsed then return nil end

  return BasicHelpers.pad(parsed.x, padlen) .. "." .. BasicHelpers.pad(parsed.y, padlen)
end

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
  local max_coord = 2000000
  if math.abs(map_position.x) > max_coord or math.abs(map_position.y) > max_coord then
    return false, "Position coordinates are outside reasonable world bounds"
  end

  return true
end

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

  local pos_valid, pos_error = GPSUtils.validate_map_position(map_position)
  if not pos_valid then
    return false, pos_error
  end
  local chunk = { x = math.floor(map_position.x / 32), y = math.floor(map_position.y / 32) }
  if not player.force.is_chunk_charted(player.surface, chunk) then
    return false, "You are trying to create a tag in uncharted territory"
  end

  return true
end

return GPSUtils
