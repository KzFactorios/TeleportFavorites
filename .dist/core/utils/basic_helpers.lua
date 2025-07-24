---@diagnostic disable: undefined-global



local Constants = require("constants")


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


function basic_helpers.is_whole_number(n)
  if type(n) ~= "number" then return false end
  return n == math.floor(n)
end


function basic_helpers.trim(s)
  if type(s) ~= "string" then return "" end
  return s:match("^%s*(.-)%s*$") or ""
end

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


function basic_helpers.is_locked_favorite(fav)
  return fav and fav.locked == true
end

function basic_helpers.is_blank_favorite(fav)
  return not fav or fav.gps == nil or fav.gps == "" or fav.gps == Constants.settings.BLANK_GPS
end
function basic_helpers.truncate_rich_text(text, max_display)
  if not text or text == "" then return "" end
  local display_count = 0
  local out = ""
  local i = 1
  while i <= #text and display_count < max_display do
    local tag_start, tag_end = string.find(text, "%[.-%]", i)
    if tag_start == i then
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


---@param player LuaPlayer The player to check
---@return boolean should_hide_bar True if the bar should be hidden

---@param player LuaPlayer The player to check
---@return boolean should_hide_bar True if the bar should be hidden
function basic_helpers.should_hide_favorites_bar_for_space_platform(player)
  if not player or not player.valid then return false end

  if player.render_mode == defines.render_mode.chart or player.render_mode == defines.render_mode.chart_zoomed_in then
    return false
  end

  local surface = player.surface
  if surface and surface.valid then
    if surface.platform ~= nil then
      return true
    end
    if player.controller_type == defines.controllers.editor then
      local surface_name = surface.name or ""
      if surface_name:lower():find("space") or surface_name:lower():find("platform") then
        return true
      end
    end
  end
  return false
end


---@param player any
---@return boolean is_valid
function basic_helpers.is_valid_player(player)
  return player ~= nil and player.valid == true
end

---@param element any
---@return boolean is_valid
function basic_helpers.is_valid_element(element)
  return element ~= nil and element.valid == true
end

---@param gps any
---@return boolean is_valid
function basic_helpers.is_valid_gps(gps)
  return gps ~= nil and gps ~= ""
end


function basic_helpers.register_commands(command_list)
  for _, command_def in ipairs(command_list) do
    local name, description, handler = command_def[1], command_def[2], command_def[3]
    commands.add_command(name, description, handler)
  end
end

function basic_helpers.create_handler_wrapper(module, method_name)
  return function(cmd)
    return module[method_name](cmd)
  end
end

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

return basic_helpers
