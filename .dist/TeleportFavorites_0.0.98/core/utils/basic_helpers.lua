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
function basic_helpers.truncate_rich_text(text, max_display)
  if not text or text == "" then return "" end
  local display_count = 0
  local out = ""
  local i = 1
  while i <= #text and display_count < max_display do
    local tag_start, tag_end = string.find(text, "%[.-%]", i)
    if tag_start == i then
      if display_count + 3 > max_display then
        out = out .. "..."
        break
      end
      out = out .. string.sub(text, tag_start, tag_end)
      display_count = display_count + 3
      i = tag_end + 1
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
function basic_helpers.is_planet_surface(surface)
  if not surface or not surface.valid then return false end
  return surface.planet ~= nil and surface.platform == nil
end
function basic_helpers.is_space_platform_surface(surface)
  if not surface or not surface.valid then return false end
  return surface.platform ~= nil
end
function basic_helpers.is_supported_controller(player)
  if not player or not player.valid then return false end
  local ct = player.controller_type
  return ct == defines.controllers.character or ct == defines.controllers.remote or ct == defines.controllers.cutscene
end
function basic_helpers.is_restricted_controller(player)
  if not player or not player.valid then return false end
  local ct = player.controller_type
  return ct == defines.controllers.god or ct == defines.controllers.spectator
end
function basic_helpers.is_valid_player(player)
  if player == nil then return false, "Player is nil" end
  if not player.valid then return false, "Player is not valid" end
  return true
end
function basic_helpers.is_valid_element(element)
  return element ~= nil and element.valid == true
end
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
function basic_helpers.deep_copy(orig)
  if type(orig) ~= 'table' then return orig end
  local copy = {}
  for k, v in pairs(orig) do
    copy[k] = (type(v) == 'table') and basic_helpers.deep_copy(v) or v
  end
  return copy
end
function basic_helpers.safe_player_print(player, message)
  if not basic_helpers.is_valid_player(player) then return false end
  if not player or type(player.print) ~= "function" then return false end
  local success = pcall(function() player.print(message) end)
  return success
end
function basic_helpers.format_error_message(error_key)
  return "[TeleportFavorites] " .. tostring(error_key)
end
function basic_helpers.safe_play_sound(player, sound)
  if player and player.valid and type(player.play_sound) == "function" and type(sound) == "table" then
    local success, err = pcall(function() player.play_sound(sound, {}) end)
    if not success then
      log("[TeleportFavorites] Failed to play sound for player " ..
        tostring(player.name) .. ": " .. tostring(err))
    end
  end
end
function basic_helpers.player_print(player, message)
  if player and player.valid and type(player.print) == "function" then
    pcall(function() player.print(message) end)
  end
end
local _LOCALE_PREFIXES = {
  gui = "tf-gui", error = "tf-error", command = "tf-command",
  handler = "tf-handler", setting_name = "mod-setting-name",
  setting_desc = "mod-setting-description"
}
function basic_helpers.substitute_parameters(text, params)
  if not text or not params then return text or "" end
  if type(params) == "table" then
    for i, value in ipairs(params) do
      text = text:gsub("__" .. i .. "__", tostring(value))
    end
    for key, value in pairs(params) do
      if type(key) == "string" then text = text:gsub("__" .. key .. "__", tostring(value)) end
    end
  end
  return text
end
function basic_helpers.get_fallback_string(category, key, params)
  local fallbacks = {
    gui = { confirm = "Confirm", cancel = "Cancel", close = "Close", delete_tag = "Delete Tag",
            teleport_success = "Teleported successfully!", teleport_failed = "Teleportation failed" },
    error = { driving_teleport_blocked = "Are you crazy? Trying to teleport while driving is strictly prohibited.",
              player_missing = "Unable to teleport. Player is missing", unknown_error = "Unknown error",
              move_mode_failed = "Move failed", invalid_location_chosen = "invalid location chosen" },
    command = { nothing_to_undo = "No actions to undo" }
  }
  local fallback = fallbacks[category] and fallbacks[category][key]
  if fallback then
    return params and type(params) == "table" and basic_helpers.substitute_parameters(fallback, params) or fallback
  end
  return "[" .. (category or "unknown") .. ":" .. (key or "unknown") .. "]"
end
function basic_helpers.get_string(player, category, key, params)
  if not basic_helpers.is_valid_player(player) then
    return basic_helpers.get_fallback_string(category, key, params)
  end
  local prefix = _LOCALE_PREFIXES[category]
  if not prefix then return key end
  local locale_key = prefix .. "." .. key
  if params and type(params) == "table" and #params > 0 then
    return { locale_key, (table.unpack or unpack)(params) }
  else
    return { locale_key }
  end
end
function basic_helpers.get_gui_string(player, key, params)
  return basic_helpers.get_string(player, "gui", key, params)
end
function basic_helpers.get_error_string(player, key, params)
  return basic_helpers.get_string(player, "error", key, params)
end
function basic_helpers.format_tag_position_change_notification(player, chart_tag, old_position, new_position)
  if not basic_helpers.is_valid_player(player) then return "[LocaleUtils] Invalid player for notification" end
  local tag_text = (chart_tag and chart_tag.text) or ""
  local old_x = old_position and math.floor(old_position.x or 0) or 0
  local old_y = old_position and math.floor(old_position.y or 0) or 0
  local new_x = new_position and math.floor(new_position.x or 0) or 0
  local new_y = new_position and math.floor(new_position.y or 0) or 0
  return basic_helpers.get_gui_string(player, "tag_position_changed", {tag_text, old_x, old_y, new_x, new_y})
end
function basic_helpers.for_each_player_by_index_asc(callback)
  if not game or not game.players or type(callback) ~= "function" then return end
  local indices = {}
  for _, player in pairs(game.players) do
    if player and player.valid then
      indices[#indices + 1] = player.index
    end
  end
  table.sort(indices)
  for i = 1, #indices do
    local pindex = indices[i]
    local player = game.players[pindex]
    if player and player.valid then
      callback(player, pindex)
    end
  end
end
function basic_helpers.for_each_connected_player_by_index_asc(callback)
  if not game or not game.players or type(callback) ~= "function" then return end
  local indices = {}
  for _, player in pairs(game.players) do
    if player and player.valid and player.connected then
      indices[#indices + 1] = player.index
    end
  end
  table.sort(indices)
  for i = 1, #indices do
    local pindex = indices[i]
    local player = game.players[pindex]
    if player and player.valid and player.connected then
      callback(player, pindex)
    end
  end
end
function basic_helpers.error_message_to_player(player, error_key, _context)
  if not basic_helpers.is_valid_player(player) then return end
  local message_text = basic_helpers.format_error_message(error_key)
  basic_helpers.safe_player_print(player, message_text)
end
function basic_helpers.with_valid_player(player_index, handler_fn, ...)
  if not player_index then return nil end
  local player = game.players[player_index]
  if not basic_helpers.is_valid_player(player) then return nil end
  return handler_fn(player, ...)
end
return basic_helpers
