--[[
helpers_suite.lua
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
function Helpers.format_sprite_path(type_or_icon, name, is_signal)
  -- If called with only one argument, treat as icon string (for backward compatibility)
  local icon = name and tostring(name) or tostring(type_or_icon)
  -- If icon contains a slash, assume it's a full sprite path (e.g. 'item/iron-plate', 'utility/lock')
  if icon:find("/") then
    return icon
  elseif icon:match("^utility%.") then
    return icon:gsub("^utility%.", "utility/")
  elseif icon:match("^item%.") then
    local item_name = icon:match("^item%.(.+)$")
    -- For custom slot button icons, return as-is (no prefix)
    return item_name or icon
  elseif icon:match("^virtual%-signal%.") then
    return icon:gsub("^virtual%-signal%.", "virtual-signal/")
  else
    return icon
  end
end

-- Table helpers
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
    if v == value then
      table.remove(tbl, i); return true
    end
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
    if type(item) == "table" then
      item.slot_num = i; arr[#arr + 1] = item
    end
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

-- Table utilities (already present, but ensure all are here and DRY)
function Helpers.table_find(tbl, value)
  if type(tbl) ~= "table" then return nil end
  for k, v in pairs(tbl) do if v == value then return k end end
  return nil
end

function Helpers.table_remove_value(tbl, value)
  if type(tbl) ~= "table" then return false end
  for k, v in pairs(tbl) do
    if v == value then
      if type(k) == "number" then table.remove(tbl, k) else tbl[k] = nil end
      return true
    end
  end
  return false
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
  if type(player) == "table" or type(player) == "userdata" and player.index then return player.index end
  return math.floor(tonumber(player) or 0)
end

function Helpers.normalize_surface_index(surface)
  if type(surface) == "table" or type(surface) == "userdata" and surface.index then return surface.index end
  return math.floor(tonumber(surface) or 0)
end

---
-- Centralized error handling and user feedback
-- @param player LuaPlayer|nil: The player to notify (optional)
-- @param message string|table: The error or info message to show
-- @param level string: 'error', 'info', or 'warn' (default: 'error')
-- @param log_to_console boolean: Whether to log to Factorio console (default: true)
function Helpers.handle_error(player, message, level, log_to_console)
  level = level or 'error'
  log_to_console = log_to_console ~= false
  local msg = (type(message) == 'table' and table.concat(message, ' ')) or tostring(message)
  if player and player.valid and type(player.print) == 'function' then
    if level == 'error' then
      player.print({ '', '[color=red][ERROR] ', msg, '[/color]' }, { r = 1, g = 0.2, b = 0.2 })
    elseif level == 'warn' then
      player.print({ '', '[color=orange][WARN] ', msg, '[/color]' }, { r = 1, g = 0.5, b = 0 })
    else
      player.print({ '', '[color=white][INFO] ', msg, '[/color]' }, { r = 1, g = 1, b = 1 })
    end
  end
  if log_to_console then
    -- Fallback to print() for logging
    local log_msg = '[TeleportFavorites][' .. level:upper() .. '] ' .. msg
    print(log_msg)
  end
end

function Helpers.safe_teleport(player, pos, surface)
  if player and player.valid and type(player.teleport) == "function" and pos and surface then
    if pos.x and pos.y then return player.teleport({ x = pos.x, y = pos.y }, surface) end
    if pos[1] and pos[2] then return player.teleport({ x = pos[1], y = pos[2] }, surface) end
  end
  return false
end

-- Safe GUI destruction
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

-- Player print (already present, but ensure DRY)
function Helpers.player_print(player, message)
  if player and player.valid and type(player.print) == "function" then player.print(message) end
end

-- Tag/favorite state update logic
function Helpers.update_favorite_state(player, tag, is_favorite, PlayerFavorites)
  -- PlayerFavorites is required to avoid circular require
  if not PlayerFavorites or not player or not tag then return end
  local pfaves = PlayerFavorites.new(player)
  if is_favorite then
    pfaves:add_favorite(tag.gps)
  else
    pfaves:remove_favorite(tag.gps)
  end
end

function Helpers.update_tag_chart_fields(tag, text, icon, player)
  tag.chart_tag = tag.chart_tag or {}
  tag.chart_tag.text = text
  tag.chart_tag.icon = icon
  tag.chart_tag.last_user = (not tag.chart_tag.last_user or tag.chart_tag.last_user == "") and player.name or
      tag.chart_tag.last_user
end

function Helpers.update_tag_position(tag, pos, gps)
  tag.chart_tag = tag.chart_tag or {}
  tag.chart_tag.position = pos
  tag.gps = gps
end

-- Error label/message handling
function Helpers.show_error_label(parent, message)
  if not parent or not message then return end
  local label = parent.error_row_error_message or parent.add {
    type = "label", name = "error_row_error_message", caption = "", style = "bold_label"
  }
  label.caption = message or ""
  label.style.font_color = { r = 1, g = 0.2, b = 0.2 }
  label.visible = (message and message ~= "")
  return label
end

function Helpers.clear_error_label(parent)
  if parent and parent.error_row_error_message then
    parent.error_row_error_message.caption = ""
    parent.error_row_error_message.visible = false
  end
end

-- Button state/style logic
function Helpers.set_button_state(element, enabled, style_overrides)
  if not element or not element.valid then
    -- Defensive: print to console if available, otherwise do nothing
    if _G and _G.print then _G.print("[TeleportFavorites] set_button_state: element is nil or invalid") end
    return
  end
  if not (element.type == "button" or element.type == "sprite-button" or element.type == "textfield" or element.type == "text-box") then
    if _G and _G.print then
      _G.print("[TeleportFavorites] set_button_state: Unexpected element type: " ..
        tostring(element.type) .. " (name: " .. tostring(element.name) .. ")")
    end
    return
  end
  -- Only set .enabled for elements that support it
  element.enabled = enabled ~= false
  -- Only apply style overrides for buttons
  if (element.type == "button" or element.type == "sprite-button") and style_overrides and type(style_overrides) == "table" then
    for k, v in pairs(style_overrides) do
      element.style[k] = v
    end
  end
end

-- Tooltip construction
function Helpers.build_favorite_tooltip(fav, opts)
  opts = opts or {}
  local gps_str = fav and fav.gps or opts.gps or "?"
  local tag_text = fav and fav.tag and fav.tag.text or opts.text or nil
  if type(tag_text) == "string" and #tag_text > (opts.max_len or 50) then
    tag_text = tag_text:sub(1, opts.max_len or 50) .. "..."
  end
  if fav and fav.locked then
    return { "tf-gui.fave_slot_locked_tooltip", gps_str, tag_text or "" }
  elseif tag_text then
    return { "tf-gui.fave_slot_tooltip", gps_str, tag_text }
  else
    return { "tf-gui.fave_slot_tooltip_one", gps_str }
  end
end

-- Slot button creation and styling
function Helpers.create_slot_button(parent, name, icon, tooltip, opts)
  opts = opts or {}
  -- Use format_sprite_path for robust sprite path handling
  local sprite = Helpers.format_sprite_path(icon)
  if not sprite or sprite == "" or sprite == "nil" then
    -- Do not set the sprite property if no valid icon is provided
    return parent.add {
      type = "sprite-button",
      name = name,
      tooltip = tooltip,
      style = opts.style or "tf_slot_button"
    }
  end
  local btn = parent.add {
    type = "sprite-button",
    name = name,
    sprite = sprite,
    tooltip = tooltip,
    style = opts.style or "tf_slot_button"
  }
  btn.style.width = opts.width or 36
  btn.style.height = opts.height or 36
  btn.style.font = opts.font or "default-small"
  if opts.enabled ~= nil then btn.enabled = opts.enabled end
  if opts.border_color then btn.style.border_color = opts.border_color end
  if opts.locked then
    local lock_icon = btn.add { type = "sprite", sprite = "utility/lock", name = "lock_overlay" }
    lock_icon.style.width, lock_icon.style.height = 16, 16
    lock_icon.style.left_margin, lock_icon.style.top_margin = 0, 0
    lock_icon.ignored_by_interaction = true
  elseif btn.lock_overlay then
    btn.lock_overlay.destroy()
  end
  return btn
end

-- Pretty-print a table (for debug/data viewer)
function Helpers.pretty_table(tbl, indent)
  indent = indent or ""
  if type(tbl) ~= "table" then return tostring(tbl) end
  local lines = {}
  for k, v in pairs(tbl) do
    table.insert(lines, indent .. tostring(k) .. ": " .. (type(v) == "table" and "{...}" or tostring(v)))
  end
  return table.concat(lines, "\n")
end

function Helpers.safe_pretty_table(tbl, indent)
  return tbl and Helpers.pretty_table(tbl, indent) or "<nil>"
end

return Helpers
