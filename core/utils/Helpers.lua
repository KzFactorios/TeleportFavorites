-- Helpers.lua
-- Utility functions for math, tables, strings, and general helpers used throughout the mod.
-- Provides static methods only. All helpers are namespaced under Helpers.
--
-- Math helpers: rounding, snapping, floor, etc.
-- Table helpers: deep/shallow copy, equality, indexed array creation, sorting, searching, removal
-- String helpers: splitting, trimming, nonempty check, padding
-- Position helpers: chunk/map conversion, position simplification
-- Tagging helpers: tag placement, collision, water/space checks

local GPS = require("core.gps.gps")

--- Static helper class for utility functions used throughout the mod.
---@class Helpers
local Helpers = {}

--- Round a number to the nearest integer (0.5 rounds up for positive, down for negative)
---@param n number
---@return number
function Helpers.math_round(n)
  if type(n) ~= "number" then return 0 end
  local rounded = n >= 0 and math.floor(n + 0.5) or math.ceil(n - 0.5)
  if tostring(rounded) == "-0" then
    rounded = 0
  end
  return rounded
end

--- Format a sprite path for Factorio, with type and name
---@param type string
---@param name string
---@param is_signal boolean?
---@return string
function Helpers.format_sprite_path(type, name, is_signal)
  -- TODO what to do if type is signal?
  if not name then name = "" end
  if not type then type = "" end
  if type == "" and not is_signal then type = "item" end
  if type == "virtual" then
    type = "virtual-signal"
  end
  local sprite_path = (type ~= "" and (type .. "/") or "") .. name
  -- Use the factorio helpers
  if not (_G.helpers and _G.helpers.is_valid_sprite_path and _G.helpers.is_valid_sprite_path(sprite_path)) then
    -- TODO better user messaging on error
    return ""
  end
  return sprite_path
end

-- TABLES
--- Deep equality check for two Lua tables (objects)
---@param a table
---@param b table
---@return boolean
function Helpers.tables_equal(a, b)
  if a == b then return true end
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  for k, v in pairs(a) do
    if type(v) == "table" and type(b[k]) == "table" then
      if not Helpers.tables_equal(v, b[k]) then return false end
    elseif v ~= b[k] then
      return false
    end
  end
  for k in pairs(b) do
    if a[k] == nil then return false end
  end
  return true
end

--- Deep copy a table (shallow for non-tables)
---@param orig any
---@return any
function Helpers.deep_copy(orig)
  if type(orig) ~= 'table' then return orig end
  local copy = {}
  for k, v in pairs(orig) do
    if type(v) == 'table' then
      copy[k] = Helpers.deep_copy(v)
    else
      copy[k] = v
    end
  end
  return copy
end

--- Shallow copy a table
---@param tbl table
---@return table
function Helpers.shallow_copy(tbl)
  local t = {}
  for k, v in pairs(tbl) do t[k] = v end
  return t
end

--- Remove the first occurrence of a value from a table (array part)
---@param tbl table
---@param value any
---@return boolean
function Helpers.remove_first(tbl, value)
  for i, v in ipairs(tbl) do
    if v == value then
      table.remove(tbl, i); return true
    end
  end
  return false
end

--- Check if a table is empty
---@param tbl table
---@return boolean
function Helpers.table_is_empty(tbl)
  if type(tbl) ~= "table" then return true end
  return next(tbl) == nil
end

--- Create an array of empty tables of given count
---@param count number
---@return table[]
function Helpers.create_empty_indexed_array(count)
  local arr = {}
  for i = 1, count do
    arr[i] = {}
  end
  return arr
end

--- Sort an array of tables, adding slot_num as the index
---@param array table[]
---@return table[]
function Helpers.array_sort_by_index(array)
  local arr = {}
  for i, item in ipairs(array) do
    if type(item) == "table" then
      item.slot_num = i
      arr[#arr + 1] = item
    end
  end
  return arr
end

--- Check if an index is present in a table (returns true and key if found)
---@param _table table
---@param idx any
---@return boolean, any
function Helpers.index_is_in_table(_table, idx)
  if type(_table) == "table" then
    for x, v in pairs(_table) do
      if v == idx then
        return true, x
      end
    end
  end
  return false, -1
end

--- Find the first value in a table matching a predicate
---@param _table table
---@param predicate fun(value:any, key:any):boolean
---@return any, any
function Helpers.find_by_predicate(_table, predicate)
  if type(_table) ~= "table" or type(predicate) ~= "function" then
    return nil, nil
  end
  for k, v in pairs(_table) do
    if predicate(v, k) then
      return v, k
    end
  end
  return nil, nil
end

-- STRINGS

--- Trim leading and trailing whitespace from a string
---@param s string
---@return string
function Helpers.trim(s)
  if type(s) ~= "string" then return s end
  local trimmed = s:match("^%s*(.-)%s*$")
  return trimmed or ""
end

--- Split a string by a delimiter
---@param str string
---@param delimiter string
---@return string[]
function Helpers.split_string(str, delimiter)
  local result = {}
  if type(str) ~= "string" or type(delimiter) ~= "string" or delimiter == "" then
    return result
  end
  local pattern = string.format("([^%s]+)", delimiter:gsub("%%", "%%%%"))
  for match in str:gmatch(pattern) do
    table.insert(result, match)
  end
  return result
end

--- Check if a string is nonempty and not just whitespace
---@param s string
---@return boolean
function Helpers.is_nonempty_string(s)
  return type(s) == "string" and s:match("%S") ~= nil
end

--- Pad a number string to at least `padlen` digits, preserving minus sign if negative
---@param n number
---@param padlen number
---@return string
function Helpers.pad(n, padlen)
  local floorn = math.floor(n + 0.5)
  local absn = math.abs(floorn)
  local s = tostring(absn)
  padlen = math.floor(padlen or 3)
  if #s < padlen then
    s = string.rep("0", padlen - #s) .. s
  end
  if floorn < 0 then
    s = "-" .. s
  end
  return s
end

--- Returns true if a string contains a decimal point
---@param s string|number
---@return boolean
function Helpers.has_decimal_point(s)
  return tostring(s):find("%.") ~= nil
end

-- POSITIONING

--- Simplify a position by rounding x and y if they are decimal
---@param pos table
---@return table
function Helpers.simplify_position(pos)
  local x = tonumber((pos and type(pos.x) == "number" or pos and type(pos.x) == "string") and pos.x or 0) or 0
  local y = tonumber((pos and type(pos.y) == "number" or pos and type(pos.y) == "string") and pos.y or 0) or 0
  if Helpers.has_decimal_point(tostring(x)) then
    x = Helpers.math_round(x)
  end
  if Helpers.has_decimal_point(tostring(y)) then
    y = Helpers.math_round(y)
  end
  return { x = x, y = y }
end

--- Snap a position to a grid of given scale
---@param Helpers table  -- expects a table with x and y
---@param snap_scale number
---@return table
function Helpers.snap_position(Helpers, snap_scale)
  return {
    x = Helpers.math_round(Helpers.x / snap_scale) * snap_scale,
    y = Helpers.math_round(Helpers.y / snap_scale) * snap_scale
  }
end

--- Convert a map position to chunk position
---@param map_pos table
---@return table
function Helpers.map_position_to_chunk_position(map_pos)
  return {
    x = math.floor(map_pos.x / 32),
    y = math.floor(map_pos.y / 32)
  }
end

--- Convert a chunk position to map position
---@param chunk_pos table
---@return table
function Helpers.chunk_position_to_map_position(chunk_pos)
  return {
    x = chunk_pos.x * 32,
    y = chunk_pos.y * 32
  }
end

-- Tagging and map position helpers

--- Returns true if a tag can be placed at the given map position for the player
---@param player LuaPlayer
---@param map_position table
---@return boolean
function Helpers.position_can_be_tagged(player, map_position)
  if not player then return false end
  local chunk_position = {
    x = math.floor(map_position.x / 32),
    y = math.floor(map_position.y / 32)
  }
  if not (player.force and player.surface and player.force.is_chunk_charted) then
    return false
  end
  if not player.force:is_chunk_charted(player.surface, chunk_position) then
    player.print(player,
      "[TeleportFavorites] You are trying to create a tag in uncharted territory: " ..
      GPS.map_position_to_gps(map_position))
    return false
  end
  local tile = player.surface.get_tile(player.surface, math.floor(map_position.x), math.floor(map_position.y))
  for _, mask in pairs(tile.prototype.collision_mask) do
    if mask == "water-tile" then
      return false
    end
  end
  return true
end

--- Returns true if the player is on a space platform (stub, always returns false unless you have space platforms mod integration)
---@param player LuaPlayer
---@return boolean
function Helpers.is_on_space_platform(player)
  -- If you have a space platform mod, check for the surface name or property here
  if not player or not player.surface or not player.surface.name then return false end
  -- Example: if surface name contains 'space' or is exactly 'space-platform'
  local name = player.surface.name:lower()
  return name:find("space") ~= nil or name == "space-platform"
end

--- Returns the position of a colliding tag if present, or nil
---@param player LuaPlayer
---@param map_position table
---@param snap_scale number
---@return table|nil
function Helpers.position_has_colliding_tag(player, map_position, snap_scale)
  if not player then return nil end
  local collision_area = {
    left_top = {
      x = map_position.x - snap_scale + 0.1,
      y = map_position.y - snap_scale + 0.1
    },
    right_bottom = {
      x = map_position.x + snap_scale - 0.1,
      y = map_position.y + snap_scale - 0.1
    }
  }
  local colliding_tags = player.force:find_chart_tags(player.surface, collision_area)
  if colliding_tags and #colliding_tags > 0 then
    return colliding_tags[1]
  end
  return nil
end

--- Returns true if the given position is a water tile
---@param surface LuaSurface
---@param pos table
---@return boolean
function Helpers.is_water_tile(surface, pos)
  local tile = surface:get_tile(math.floor(pos.x), math.floor(pos.y))
  ---@diagnostic disable-next-line
  if tile and tile.prototype and tile.prototype.collision_mask then
    for _, mask in pairs(tile.prototype.collision_mask) do
      if mask == "water-tile" then
        return true
      end
    end
  end

  return false
end

--- Print a localized message to the player after teleporting
---@param event table
---@param game table
function Helpers.on_raise_teleported(event, game)
  if not event or not event.player_index then return end
  if not game or type(game.get_player) ~= "function" then return end
  local player = game.get_player(event.player_index)
  if not player then return end
  local pos = player.position or { x = 0, y = 0 }
  if type(player.print) == "function" then
    -- do not add the [TeleportFavorites] at the head of the output to reduce clutter
    local gps_string = GPS.coords_string_from_gps(GPS.gps_from_map_position(pos, player.surface.index))
    ---@diagnostic disable-next-line
    player.print({ "teleported-to", player.name, gps_string })
  end
  --Slots.update_slots(player)
end

return Helpers
