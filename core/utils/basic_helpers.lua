---@diagnostic disable: undefined-global

-- core/utils/basic_helpers.lua
-- TeleportFavorites Factorio Mod
-- Dependency-free utility functions for math, string, table, GUI, validation, and command helpers.
--
-- Key Patterns:
--   - Math, string, and table helpers
--   - GUI and validation helpers
--   - Command registration wrappers (Factorio global 'commands')
--   - Deep copy and table comparison
--   - No leading underscores for private fields
--   - No circular dependencies


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

function basic_helpers.is_locked_favorite(fav)
  return fav and fav.locked == true
end

function basic_helpers.is_blank_favorite(fav)
  return not fav or fav.gps == nil or fav.gps == "" or fav.gps == "1000000.1000000.1" -- Constants.settings.BLANK_GPS
end
--- Truncates a string containing rich text tags, counting each tag as 3 display spaces
--- @param text string
--- @param max_display number
--- @return string
function basic_helpers.truncate_rich_text(text, max_display)
  if not text or text == "" then return "" end
  local display_count = 0
  local out = ""
  local i = 1
  while i <= #text and display_count < max_display do
    local tag_start, tag_end = string.find(text, "%[.-%]", i)
    if tag_start == i then
      -- Found a rich text tag at current position
      if type(tag_start) == "number" and type(tag_end) == "number" then
        if display_count + 3 > max_display then
          out = out .. "..."
          break
        end
        out = out .. string.sub(text, tag_start, tag_end)
        display_count = display_count + 3
        i = tag_end + 1
      else
        out = out .. "..."
        break
      end
    else
      out = out .. string.sub(text, i, i)
      display_count = display_count + 1
      i = i + 1
    end
    if display_count >= max_display then
      out = out .. "..."
      break
    end
  end
  return out
end


function basic_helpers.update_error_message(update_fn, player, message)
  if update_fn and player then update_fn(player, message) end
end

function basic_helpers.update_state(update_fn, player, state)
  if update_fn then update_fn(player, state) end
end

-- ===========================
-- SPACE PLATFORM DETECTION
-- ===========================

--- Check if player should have favorites bar hidden due to remote view of a space platform (Factorio 2.0+)
---@param player LuaPlayer The player to check
---@return boolean should_hide_bar True if the bar should be hidden
function basic_helpers.should_hide_favorites_bar_for_space_platform(player)
  if not player or not player.valid then return false end

  -- MULTIPLAYER FIX: Removed player.render_mode check - it's client-specific and causes desyncs!
  -- The bar visibility should only depend on surface properties, not view mode.
  
  local surface = player.surface
  if surface and surface.valid then
    -- Hide for any space platform surface in any mode (except chart views)
    if surface.platform ~= nil then
      return true
    end
    -- Hide in editor mode if surface name contains 'space' or 'platform'
    if player.controller_type == defines.controllers.editor then
      local surface_name = surface.name or ""
      if surface_name:lower():find("space") or surface_name:lower():find("platform") then
        return true
      end
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

-- ===========================
-- SAFE PLAYER PRINT & ERROR MESSAGE HELPERS
-- ===========================

--- Safely print a message to a player (no dependencies)
---@param player LuaPlayer|nil The player to send message to
---@param message LocalisedString|string The message to send
---@return boolean success
function basic_helpers.safe_player_print(player, message)
  if not basic_helpers.is_valid_player(player) then return false end
  if not player or type(player.print) ~= "function" then return false end
  local success = pcall(function() player.print(message) end)
  return success
end

--- Standardized error message formatting
---@param error_key string Error localization key or raw message
---@return string formatted_message
function basic_helpers.format_error_message(error_key)
  return "[TeleportFavorites] " .. tostring(error_key)
end

return basic_helpers
