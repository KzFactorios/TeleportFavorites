---@diagnostic disable: undefined-global

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

local Enum = require("prototypes.enums.enum")

---@class Helpers
local Helpers = {}

-- Math helpers
function Helpers.math_round(n)
  if type(n) ~= "number" then return 0 end
  local rounded = n >= 0 and math.floor(n + 0.5) or math.ceil(n - 0.5)
  return tostring(rounded) == "-0" and 0 or rounded
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

--- Returns the value and the index of the first element in the table that matches the predicate function.
--- If no match is found, returns nil, nil.
---@param _table table: The table to search
---@param predicate function: A function that takes two arguments (value, key) and returns true if it matches
---@return any, number: The value and key_index of the first matching element, or nil if not found
function Helpers.find_by_predicate(_table, predicate)
  if type(_table) ~= "table" or type(predicate) ~= "function" then return nil, 0 end
  for k, v in pairs(_table) do if predicate(v, k) then return v, k end end
  return nil, 0
end

function Helpers.table_count(t)
  local n = 0
  if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end
  return n
end

-- Table utilities with functional programming patterns
function Helpers.table_find(tbl, value)
  if type(tbl) ~= "table" then return nil end
  local function value_matcher(v, k)
    return v == value and k or nil
  end
  return Helpers.find_first_match(tbl, value_matcher)
end

function Helpers.table_remove_value(tbl, value)
  if type(tbl) ~= "table" then return false end
  local function remove_matching_value(v, k)
    if v == value then
      if type(k) == "number" then 
        table.remove(tbl, k) 
      else 
        tbl[k] = nil 
      end
      return true
    end
    return false
  end
  return Helpers.process_until_match(tbl, remove_matching_value)
end

--- Generic helper: Find first match using a matcher function
--- @param tbl table
--- @param matcher_func function Function that takes (value, key) and returns result or nil
--- @return any
function Helpers.find_first_match(tbl, matcher_func)
  if type(tbl) ~= "table" or type(matcher_func) ~= "function" then return nil end
  for k, v in pairs(tbl) do 
    local result = matcher_func(v, k)
    if result ~= nil then return result end
  end
  return nil
end

--- Generic helper: Process table until a condition is met
--- @param tbl table
--- @param processor_func function Function that takes (value, key) and returns true to stop processing
--- @return boolean True if condition was met
function Helpers.process_until_match(tbl, processor_func)
  if type(tbl) ~= "table" or type(processor_func) ~= "function" then return false end
  for k, v in pairs(tbl) do 
    if processor_func(v, k) then return true end
  end
  return false
end

-- Functional programming utilities for collections
--- Map function: transform each element in a table using a mapper function
--- @param tbl table
--- @param mapper_func function Function that takes (value, key) and returns transformed value
--- @return table New table with transformed values
function Helpers.map(tbl, mapper_func)
  if type(tbl) ~= "table" or type(mapper_func) ~= "function" then return {} end
  local result = {}
  for k, v in pairs(tbl) do
    result[k] = mapper_func(v, k)
  end
  return result
end

--- Filter function: select elements that match a predicate
--- @param tbl table
--- @param predicate_func function Function that takes (value, key) and returns boolean
--- @return table New table with filtered values
function Helpers.filter(tbl, predicate_func)
  if type(tbl) ~= "table" or type(predicate_func) ~= "function" then return {} end
  local result = {}
  for k, v in pairs(tbl) do
    if predicate_func(v, k) then
      result[k] = v
    end
  end
  return result
end

--- Reduce function: accumulate values using a reducer function
--- @param tbl table
--- @param reducer_func function Function that takes (accumulator, value, key) and returns new accumulator
--- @param initial_value any Initial value for the accumulator
--- @return any Final accumulated value
function Helpers.reduce(tbl, reducer_func, initial_value)
  if type(tbl) ~= "table" or type(reducer_func) ~= "function" then return initial_value end
  local accumulator = initial_value
  for k, v in pairs(tbl) do
    accumulator = reducer_func(accumulator, v, k)
  end
  return accumulator
end

--- ForEach function: execute a function for each element without returning anything
--- @param tbl table
--- @param action_func function Function that takes (value, key)
function Helpers.for_each(tbl, action_func)
  if type(tbl) ~= "table" or type(action_func) ~= "function" then return end
  for k, v in pairs(tbl) do
    action_func(v, k)
  end
end

--- Partition function: split table into two based on predicate
--- @param tbl table
--- @param predicate_func function Function that takes (value, key) and returns boolean
--- @return table, table Two tables: {matching}, {not_matching}
function Helpers.partition(tbl, predicate_func)
  if type(tbl) ~= "table" or type(predicate_func) ~= "function" then 
    return {}, {} 
  end
  local matching, not_matching = {}, {}
  for k, v in pairs(tbl) do
    if predicate_func(v, k) then
      matching[k] = v
    else
      not_matching[k] = v
    end
  end
  return matching, not_matching
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
  local colliding_tags = player.force.find_chart_tags(player.surface, collision_area)
  if colliding_tags and Helpers.table_count(colliding_tags) > 0 then return colliding_tags[1] end
  return nil
end

function Helpers.is_water_tile(surface, pos)
  if not surface or not surface.get_tile then return false end
  local tile = surface.get_tile(math.floor(pos.x), math.floor(pos.y))
  if tile and tile.prototype and tile.prototype.collision_mask then
    for _, mask in pairs(tile.prototype.collision_mask) do
      if mask == "water-tile" then return true end
    end
  end
  return false
end

function Helpers.is_space_tile(surface, pos)
  if not surface or not surface.get_tile then return false end
  local tile = surface.get_tile(math.floor(pos.x), math.floor(pos.y))
  if tile and tile.prototype and tile.prototype.collision_mask then
    for _, mask in pairs(tile.prototype.collision_mask) do
      if mask == "space" then return true end
    end
  end
  return false
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

function Helpers.safe_teleport(player, pos)
  if player and player.valid then
    if pos.x and pos.y then return player.teleport({ x = pos.x, y = pos.y }, player.surface) end
    if pos[1] and pos[2] then return player.teleport({ x = pos[1], y = pos[2] }, player.surface) end
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
    _G.print("[TeleportFavorites] set_button_state: element is nil or invalid")
    return
  end
  if not (element.type == "button" or element.type == "sprite-button" or element.type == "textfield" or element.type == "text-box") then
    _G.print("[TeleportFavorites] set_button_state: Unexpected element type: " .. tostring(element.type) .. " (name: " .. tostring(element.name) .. ")")
    return
  end
  element.enabled = enabled ~= false
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
  end
  return { "tf-gui.fave_slot_tooltip", gps_str, tag_text or "" }
end

-- Slot button creation and styling
function Helpers.create_slot_button(parent, name, icon, tooltip, opts)
  opts = opts or {}
  local sprite = icon
  -- Robust dynamic icon validation
  if sprite and sprite ~= "" then
    local is_valid = false
    if remote and remote.interfaces and remote.interfaces["__core__"] and remote.interfaces["__core__"].is_valid_sprite_path then
      is_valid = remote.call("__core__", "is_valid_sprite_path", sprite)
    else
      is_valid = true -- fallback for test/mocks
    end
    if not is_valid then
      print("[TeleportFavorites] WARNING: Invalid sprite '" .. tostring(sprite) .. "' for button '" .. tostring(name) .. "'. Using fallback icon.")
      sprite = opts.fallback_icon or nil -- fallback to nil (blank) or allow override
    end
  else
    sprite = nil -- treat empty string as no icon
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
  if opts.locked then
    local lock_sprite = (Enum.SpriteEnum and Enum.SpriteEnum["LOCK"]) or "utility/lock"
    local lock_icon = btn.add { type = "sprite", sprite = lock_sprite, name = "lock_overlay" }
    lock_icon.style.width, lock_icon.style.height = 16, 16
    lock_icon.style.left_margin, lock_icon.style.top_margin = 0, 0
    lock_icon.ignored_by_interaction = true
  elseif btn.lock_overlay then
    btn.lock_overlay.destroy()
  end
  return btn
end

--- Recursively search for a child element by name in a GUI element tree
local function find_child_by_name(parent_element, target_name)
  if not (parent_element and parent_element.valid and parent_element.children) then return nil end
  for _, child in pairs(parent_element.children) do
    if child.name == target_name then
      return child
    end
    local found = find_child_by_name(child, target_name)
    if found then return found end
  end
  return nil
end

--- Returns the name of the top-level GUI frame for a given LuaGuiElement, or nil if not found.
--- Traverses up the parent chain until it finds the matching element
--- @param element LuaGuiElement
--- @return LuaGuiElement|nil: The top-level GUI frame, or nil if not found
function Helpers.get_gui_frame_by_element(element)
  local current = element
  while current and current.valid do
    if (Enum.is_value_member_enum(current.name, Enum.GuiEnum.GUI_FRAME)) then
      return current
    end
    if not current.parent then break end
    current = current.parent
  end
  return nil
end

--- Returns the name of the top-level GUI frame for a given LuaGuiElement, or nil if not found.
--- Traverses up the parent chain until it finds the matching element
--- @param element_name string
--- @return LuaGuiElement|nil: The top-level GUI frame, or nil if not found
function Helpers.get_gui_frame_by_child_element_name(element_name)
  -- This function is not used and is broken, so remove or comment it out
  -- local element = mod_gui.get_button_flow()
  return nil
end



Helpers.find_child_by_name = find_child_by_name

return Helpers
