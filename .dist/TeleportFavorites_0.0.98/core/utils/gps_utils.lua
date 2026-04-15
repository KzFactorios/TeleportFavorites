local BasicHelpers = require("core.utils.basic_helpers")
local ErrorHandler = require("core.utils.error_handler")
local Constants = require("core.constants_impl")
local padlen, BLANK_GPS = Constants.settings.GPS_PAD_NUMBER, Constants.settings.BLANK_GPS
local GPSUtils = {}
function GPSUtils.parse_gps_string(gps)
  if type(gps) ~= "string" then return nil end
  if gps == BLANK_GPS then return { x = 0, y = 0, s = -1 } end
  local x, y, s = gps:match("^(%-?%d+)%.(%-?%d+)%.(%d+)$")
  if not x or not y or not s then return nil end
  local parsed_x, parsed_y, parsed_s = tonumber(x), tonumber(y), tonumber(s)
  if not parsed_x or not parsed_y or not parsed_s then return nil end
  return { x = parsed_x, y = parsed_y, s = parsed_s }
end
function GPSUtils.gps_from_map_position(map_position, surface_index)
  if not map_position or type(map_position.x) ~= "number" or type(map_position.y) ~= "number" then
    return tostring(BLANK_GPS)
  end
  surface_index = surface_index or 1
  local x = math.floor(map_position.x + 0.5)
  local y = math.floor(map_position.y + 0.5)
  return BasicHelpers.pad(x, padlen) .. "." .. BasicHelpers.pad(y, padlen) .. "." .. tostring(surface_index)
end
function GPSUtils.map_position_from_gps(gps)
  local parsed = GPSUtils.parse_gps_string(gps)
  if not parsed then return nil end
  return { x = parsed.x, y = parsed.y }
end
function GPSUtils.get_surface_index_from_gps(gps)
  local parsed = GPSUtils.parse_gps_string(gps)
  if not parsed then return nil end
  return parsed.s
end
function GPSUtils.coords_string_from_gps(gps)
  local parsed = GPSUtils.parse_gps_string(gps)
  if not parsed then return nil end
  return BasicHelpers.pad(parsed.x, padlen) .. "." .. BasicHelpers.pad(parsed.y, padlen)
end
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
function GPSUtils.get_context_surface_index(tag_or_event_tag, player, fallback)
  if tag_or_event_tag and tag_or_event_tag.surface and tag_or_event_tag.surface.valid then
    return tag_or_event_tag.surface.index
  end
  if player and player.valid and player.surface and player.surface.valid then
    return player.surface.index
  end
  return fallback or 1
end
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
local function get_xy(map_position)
  if type(map_position) ~= "table" then return nil, nil end
  if map_position.x ~= nil and map_position.y ~= nil then
    return map_position.x, map_position.y
  elseif type(map_position[1]) == "number" and type(map_position[2]) == "number" then
    return map_position[1], map_position[2]
  end
  return nil, nil
end
function GPSUtils.normalize_position(map_position)
  if not map_position then return nil end
  local x, y = get_xy(map_position)
  if x == nil or y == nil then return nil end
  if BasicHelpers.is_whole_number(x) and BasicHelpers.is_whole_number(y) then
    return { x = x, y = y }
  end
  return { x = math.floor(x), y = math.floor(y) }
end
function GPSUtils.needs_normalization(map_position)
  if not map_position then return false end
  local x, y = get_xy(map_position)
  if x == nil or y == nil then return false end
  return not (BasicHelpers.is_whole_number(x) and BasicHelpers.is_whole_number(y))
end
function GPSUtils.create_position_pair(position)
  return {
    old = { x = position.x, y = position.y },
    new = {
      x = BasicHelpers.normalize_index(position.x),
      y = BasicHelpers.normalize_index(position.y)
    }
  }
end
local function get_tile_name(surface, position)
  if not surface or not surface.get_tile then return nil end
  local norm = GPSUtils.normalize_position(position)
  if not norm then return nil end
  local tile = surface.get_tile(norm.x, norm.y)
  if not tile or not tile.valid then return nil end
  return tile.name:lower()
end
function GPSUtils.is_water_tile(surface, position)
  local name = get_tile_name(surface, position)
  return name ~= nil and (name:find("water") ~= nil or name:find("deepwater") ~= nil
    or name:find("shallow%-water") ~= nil)
end
function GPSUtils.is_space_tile(surface, position)
  local name = get_tile_name(surface, position)
  return name ~= nil and (name:find("space") ~= nil or name:find("void") ~= nil
    or name == "out-of-map" or name == "space-platform")
end
function GPSUtils.is_walkable_position(surface, position)
  if not surface or not position then
    ErrorHandler.debug_log("[WALKABLE] Invalid surface or position",
      { surface = surface and surface.name, position = position })
    return false
  end
  local norm_pos = GPSUtils.normalize_position(position)
  if not norm_pos or norm_pos.x == nil or norm_pos.y == nil then
    ErrorHandler.debug_log("[WALKABLE] Invalid normalized position", { position = position })
    return false
  end
  local tile = surface.get_tile(norm_pos.x, norm_pos.y)
  ErrorHandler.debug_log("[WALKABLE] Tile info", {
    surface = surface.name, orig_x = position.x, orig_y = position.y,
    norm_x = norm_pos.x, norm_y = norm_pos.y,
    tile_name = tile and tile.name or "<nil>",
    tile_valid = tile and tile.valid or false
  })
  if not tile or not tile.valid then return false end
  if GPSUtils.is_water_tile(surface, norm_pos) then return false end
  if GPSUtils.is_space_tile(surface, norm_pos) then return false end
  return true
end
return GPSUtils
