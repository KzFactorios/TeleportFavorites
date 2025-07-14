-- core/utils/basic_helpers.lua
-- Minimal, dependency-free helpers for use by other helpers

local basic_helpers = {}

function basic_helpers.pad(n, padlen)
  if type(n) ~= "number" or type(padlen) ~= "number" then return tostring(n or "") end
  local floorn = math.floor(n + 0.5)
  local absn = math.abs(floorn)
  local s = tostring(absn)
  padlen = math.floor(padlen or 3)
  if #s < padlen then s = string.rep("0", padlen - #s) .. s end
  if floorn < 0 then s = "-" .. s end
  return s
end

-- Math helpers

--- Checks if a number is a whole number (integer)
--- @param n any
--- @return boolean
function basic_helpers.is_whole_number(n)
  if type(n) ~= "number" then return false end
  return n == math.floor(n)
end

-- String helpers

--- Trims whitespace from both ends of a string
--- @param s string | any
--- @return string
function basic_helpers.trim(s)
  if type(s) ~= "string" then return "" end
  return s:match("^%s*(.-)%s*$") or ""
end

--- Splits a string into a table of substrings based on a delimiter
--- @param str string | any
--- @param delimiter string | any
--- @return table
function basic_helpers.split_string(str, delimiter)
  if type(str) ~= "string" or type(delimiter) ~= "string" then return {} end
  local result = {}
  for match in str:gmatch("[^" .. delimiter .. "]+") do
    table.insert(result, match)
  end
  return result
end

--- Checks if a string is non-empty
--- @param s any
--- @return boolean
function basic_helpers.is_nonempty_string(s)
  return type(s) == "string" and s ~= "" and s:match("^%s*(.-)%s*$") ~= ""
end

--- Ensures that an index is a valid integer (can be negative for coordinates)
--- Rounds floating point numbers to the nearest integer
--- @param index any
--- @return number?
function basic_helpers.normalize_index(index)
  if type(index) == "number" then
    return math.floor(index + 0.5)
  elseif type(index) == "string" then
    local num = tonumber(index)
    if num then
      return math.floor(num + 0.5)
    end
  end
  return nil
end

-- ===========================
-- FAVORITE SLOT UTILITIES 
-- ===========================

function basic_helpers.is_locked_favorite(fav)
  return fav and fav.locked == true
end

function basic_helpers.is_empty_favorite(fav)
  return not fav or not fav.gps or fav.gps == ""
end

function basic_helpers.is_blank_favorite(fav)
  return not fav or (not fav.gps and not fav.text)
end

-- ===========================
-- GUI HELPERS
-- ===========================

function basic_helpers.update_error_message(update_fn, player, message)
  if update_fn and player then update_fn(player, message) end
end

function basic_helpers.update_state_toggle(toggle_fn, player, state)
  if toggle_fn and player then toggle_fn(player, state) end
end

function basic_helpers.update_state(update_fn, player, state)
  if update_fn then update_fn(player, state) end
end

function basic_helpers.update_success_message(update_fn, player, message)
  if update_fn and player then update_fn(player, message) end
end

-- ===========================
-- SPACE PLATFORM DETECTION
-- ===========================

--- Check if player should have favorites bar hidden due to space platform editing
---@param player LuaPlayer The player to check
---@return boolean should_hide_bar True if the bar should be hidden
function basic_helpers.should_hide_favorites_bar_for_space_platform(player)
  if not player or not player.valid then return false end
  local surface = player.surface
  if surface and surface.platform then return true end
  if player.controller_type == defines.controllers.editor then
    local surface_name = surface and surface.name or ""
    if surface_name:lower():find("space") or surface_name:lower():find("platform") then
      return true
    end
  end
  return false
end

-- ===========================
-- SAFE VALIDATION HELPERS (from safe_helpers.lua)
-- ===========================

--- Ultra-safe player validation (no dependencies)
--- Returns true only if player exists and is valid
---@param player any 
---@return boolean is_valid
function basic_helpers.is_valid_player(player)
  return player ~= nil and player.valid == true
end

--- Ultra-safe element validation (no dependencies)  
--- Returns true only if element exists and is valid
---@param element any
---@return boolean is_valid
function basic_helpers.is_valid_element(element)
  return element ~= nil and element.valid == true  
end

--- Ultra-safe GPS string validation (no dependencies)
--- Returns true only if GPS string is not nil and not empty
---@param gps any
---@return boolean is_valid
function basic_helpers.is_valid_gps(gps)
  return gps ~= nil and gps ~= ""
end

--- Safe early return pattern - executes callback only if condition is true
--- No dependencies, can be used anywhere
---@param condition boolean
---@param callback function
---@param ... any Parameters to pass to callback
---@return any result Result from callback or nil
function basic_helpers.when_true(condition, callback, ...)
  if condition then
    return callback(...)
  end
  return nil
end

-- Command helpers

--- Register multiple commands with a cleaner syntax
--- @param command_list table List of command definitions
--- Each command definition should be: {name, description, handler}
function basic_helpers.register_commands(command_list)
  for _, command_def in ipairs(command_list) do
    local name, description, handler = command_def[1], command_def[2], command_def[3]
    commands.add_command(name, description, handler)
  end
end

--- Create a command handler wrapper that calls a method on a module
--- @param module table The module containing the handler method
--- @param method_name string The name of the method to call
--- @return function The wrapped handler function
function basic_helpers.create_handler_wrapper(module, method_name)
  return function(cmd)
    return module[method_name](cmd)
  end
end

--- Register commands for a module using a standardized pattern
--- @param module table The module containing the handlers
--- @param command_definitions table List of {name, description, handler_method_name}
function basic_helpers.register_module_commands(module, command_definitions)
  local command_list = {}
  for _, def in ipairs(command_definitions) do
    local name, description, handler_method = def[1], def[2], def[3]
    table.insert(command_list, {
      name,
      description,
      basic_helpers.create_handler_wrapper(module, handler_method)
    })
  end
  basic_helpers.register_commands(command_list)
end

-- Collection/table helpers

--- Deep comparison of two tables
---@param a table
---@param b table
---@return boolean are_equal
function basic_helpers.tables_equal(a, b)
  if a == b then return true end
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  for k, v in pairs(a) do
    if type(v) == "table" and type(b[k]) == "table" then
      if not basic_helpers.tables_equal(v, b[k]) then return false end
    elseif v ~= b[k] then
      return false
    end
  end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end

--- Create a deep copy of a table
---@param orig table
---@return table copied_table
function basic_helpers.deep_copy(orig)
  if type(orig) ~= 'table' then return orig end
  local copy = {}
  for k, v in pairs(orig) do
    copy[k] = (type(v) == 'table') and basic_helpers.deep_copy(v) or v
  end
  return copy
end

--- Create a shallow copy of a table
---@param orig table
---@return table copied_table
function basic_helpers.shallow_copy(orig)
  if type(orig) ~= 'table' then return orig end
  local copy = {}
  for k, v in pairs(orig) do
    copy[k] = v
  end
  return copy
end

--- Count elements in a table
---@param tbl table
---@return number count
function basic_helpers.table_count(tbl)
  if type(tbl) ~= "table" then return 0 end
  local count = 0
  for _ in pairs(tbl) do
    count = count + 1
  end
  return count
end

return basic_helpers
