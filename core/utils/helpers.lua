--[[
helpers.lua
TeleportFavorites Factorio Mod
-----------------------------
Comprehensive utility module for math, table, string, and general helpers used throughout the mod.

- Math: rounding, snapping, floor, etc.
- Table: deep/shallow copy, equality, indexed array creation, sorting, searching, removal, counting
- String: splitting, trimming, nonempty check, padding, decimal detection
- Position: (moved to position_helpers.lua to avoid circular dependencies)
- Tagging: tag placement, collision, water/space checks
- GUI and player helpers: safe print, teleport, frame destruction, sound

All helpers are static and namespaced under Helpers. Used pervasively for DRY, robust, and maintainable code.
]]

---@class Helpers
local Helpers = {}

-- Math helpers
function Helpers.math_round(n)
  if type(n) ~= "number" then return 0 end
  local rounded = n >= 0 and math.floor(n + 0.5) or math.ceil(n - 0.5)
  return tostring(rounded) == "-0" and 0 or rounded
end

-- Format a sprite path for Factorio, with type and name
function Helpers.format_sprite_path(type, name, is_signal)
  if not name then name = "" end
  if not type then type = "" end
  if type == "" and not is_signal then type = "item" end
  if type == "virtual" then type = "virtual-signal" end
  local sprite_path = (type ~= "" and (type .. "/") or "") .. name
  if not (_G.helpers and _G.helpers.is_valid_sprite_path and _G.helpers.is_valid_sprite_path(sprite_path)) then
    return ""
  end
  return sprite_path
end

-- Table helpers
function Helpers.tables_equal(a, b)
  if a == b then return true end
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  for k, v in pairs(a) do
    if type(v) == "table" and type(b[k]) == "table" then
      if not Helpers.tables_equal(v, b[k]) then return false end
    elseif v ~= b[k] then return false end
  end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end

function Helpers.deep_copy(orig)
  if type(orig) ~= 'table' then return orig end
  local copy = {}
  for k, v in pairs(orig) do
    copy[k] = type(v) == 'table' and Helpers.deep_copy(v) or v
  end
  return copy
end

function Helpers.shallow_copy(tbl)
  local t = {}
  for k, v in pairs(tbl) do t[k] = v end
  return t
end

function Helpers.remove_first(tbl, value)
  if type(tbl) ~= "table" then return false end
  for i, v in ipairs(tbl) do
    if v == value then table.remove(tbl, i); return true end
  end
  return false
end

function Helpers.table_is_empty(tbl)
  return type(tbl) ~= "table" or next(tbl) == nil
end

function Helpers.create_empty_indexed_array(count)
  local arr = {}
  for i = 1, count do arr[i] = {} end
  return arr
end

function Helpers.array_sort_by_index(array)
  local arr = {}
  for i, item in ipairs(array) do
    if type(item) == "table" then item.slot_num = i; arr[#arr + 1] = item end
  end
  return arr
end

function Helpers.index_is_in_table(_table, idx)
  if type(_table) == "table" then
    for x, v in pairs(_table) do if v == idx then return true, x end end
  end
  return false, -1
end

function Helpers.find_by_predicate(_table, predicate)
  if type(_table) ~= "table" or type(predicate) ~= "function" then return nil, nil end
  for k, v in pairs(_table) do if predicate(v, k) then return v, k end end
  return nil, nil
end

function Helpers.table_count(t)
  local n = 0
  if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end
  return n
end

-- String helpers
function Helpers.trim(s)
  if type(s) ~= "string" then return s end
  return s:match("^%s*(.-)%s*$") or ""
end

function Helpers.split_string(str, delimiter)
  local result = {}
  if type(str) ~= "string" or type(delimiter) ~= "string" or delimiter == "" then return result end
  local pattern = string.format("([^%s]+)", delimiter:gsub("%%", "%%%%"))
  for match in str:gmatch(pattern) do table.insert(result, match) end
  return result
end

function Helpers.is_nonempty_string(s)
  return type(s) == "string" and s:match("%S") ~= nil
end

function Helpers.pad(n, padlen)
  if type(n) ~= "number" or type(padlen) ~= "number" then return tostring(n or "") end
  local floorn = math.floor(n + 0.5)
  local absn = math.abs(floorn)
  local s = tostring(absn)
  padlen = math.floor(padlen or 3)
  if #s < padlen then s = string.rep("0", padlen - #s) .. s end
  if floorn < 0 then s = "-" .. s end
  return s
end

function Helpers.has_decimal_point(s)
  return tostring(s):find("%.") ~= nil
end

-- Positioning/tagging helpers (moved to position_helpers.lua)
function Helpers.position_can_be_tagged(player, map_position)
  return false
end

function Helpers.is_on_space_platform(player)
  if not player or not player.surface or not player.surface.name then return false end
  local name = player.surface.name:lower()
  return name:find("space") ~= nil or name == "space-platform"
end

function Helpers.position_has_colliding_tag(player, map_position, snap_scale)
  if not player then return nil end
  local collision_area = {
    left_top = { x = map_position.x - snap_scale + 0.1, y = map_position.y - snap_scale + 0.1 },
    right_bottom = { x = map_position.x + snap_scale - 0.1, y = map_position.y + snap_scale - 0.1 }
  }
  local colliding_tags = player.force:find_chart_tags(player.surface, collision_area)
  if colliding_tags and Helpers.table_count(colliding_tags) > 0 then return colliding_tags[1] end
  return nil
end

function Helpers.is_water_tile(surface, pos)
  if not surface or not surface.get_tile then return false end
  local tile = surface.get_tile(surface, math.floor(pos.x), math.floor(pos.y))
  if tile and tile.prototype and tile.prototype.collision_mask then
    for _, mask in pairs(tile.prototype.collision_mask) do
      if mask == "water-tile" then return true end
    end
  end
  return false
end

function Helpers.normalize_player_index(player)
  if type(player) == "table" and player.index then return player.index end
  return math.floor(tonumber(player) or 0)
end

function Helpers.normalize_surface_index(surface)
  if type(surface) == "table" and surface.index then return surface.index end
  return math.floor(tonumber(surface) or 0)
end

function Helpers.player_print(player, message)
  if player and player.valid and type(player.print) == "function" then player.print(message) end
end

function Helpers.safe_teleport(player, pos, surface)
  if player and player.valid and type(player.teleport) == "function" and pos and surface then
    if pos.x and pos.y then return player.teleport({x=pos.x, y=pos.y}, surface) end
    if pos[1] and pos[2] then return player.teleport({x=pos[1], y=pos[2]}, surface) end
  end
  return false
end

function Helpers.safe_destroy_frame(parent, frame_name)
  if parent and parent[frame_name] and parent[frame_name].valid and type(parent[frame_name].destroy) == "function" then
    parent[frame_name].destroy()
  end
end

function Helpers.safe_play_sound(player, sound)
  if player and player.valid and type(player.play_sound) == "function" and type(sound) == "table" then
    pcall(function() player.play_sound(sound, {}) end)
  end
end

return Helpers
