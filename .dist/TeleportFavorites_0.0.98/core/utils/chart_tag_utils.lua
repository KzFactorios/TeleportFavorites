local Deps = require("core.deps_barrel")
local BasicHelpers, ErrorHandler, Cache, GPSUtils =
  Deps.BasicHelpers, Deps.ErrorHandler, Deps.Cache, Deps.GpsUtils
local icon_type_lookup = {}
local function get_icon_type(icon)
  if not icon or type(icon) ~= "table" or not icon.name or icon.name == "" then return "item" end
  local icon_name = icon.name
  if icon_type_lookup[icon_name] then return icon_type_lookup[icon_name] end
  local icon_type = icon.type
  if icon_type == "virtual" then icon_type = "virtual_signal" end
  if icon_type and type(icon_type) == "string" and icon_type ~= "" then
    local valid_types = {
      ["item"] = true, ["fluid"] = true, ["virtual_signal"] = true, ["entity"] = true,
      ["equipment"] = true, ["technology"] = true, ["recipe"] = true, ["tile"] = true
    }
    if valid_types[icon_type] then
      local proto_table = prototypes[icon_type]
      if proto_table and proto_table[icon_name] then
        icon_type_lookup[icon_name] = icon_type
        return icon_type
      end
    end
  end
  local vanilla_types = { "item", "fluid", "virtual_signal", "entity", "equipment", "technology", "recipe", "tile" }
  for _, t in ipairs(vanilla_types) do
    local proto_table = prototypes[t]
    if proto_table and proto_table[icon_name] then
      icon_type_lookup[icon_name] = t
      return t
    end
  end
  for proto_type, proto_table in pairs(prototypes) do
    if type(proto_table) == "table" and proto_table[icon_name] then
      icon_type_lookup[icon_name] = proto_type
      return proto_type
    end
  end
  ErrorHandler.warn_log("Unknown icon type or prototype lookup failed",
    { icon = icon, icon_name = icon_name, icon_type = icon.type })
  icon_type_lookup[icon_name] = "item"
  return "item"
end
local ChartTagUtils = {}
function ChartTagUtils.find_closest_chart_tag_to_position(player, cursor_position)
  if not BasicHelpers.is_valid_player(player) or not cursor_position then return nil end
  local surface = player.surface
  if not surface or not surface.valid then return nil end
  local click_radius = Cache.Settings.get_chart_tag_click_radius()
  local area_tags = game.forces["player"].find_chart_tags(surface, {
    left_top     = { x = cursor_position.x - click_radius, y = cursor_position.y - click_radius },
    right_bottom = { x = cursor_position.x + click_radius, y = cursor_position.y + click_radius },
  })
  if not area_tags or #area_tags == 0 then return nil end
  local min_distance = math.huge
  local closest_tag  = nil
  for _, tag in ipairs(area_tags) do
    if tag and tag.valid then
      local dx = tag.position.x - cursor_position.x
      local dy = tag.position.y - cursor_position.y
      local distance = math.sqrt(dx * dx + dy * dy)
      if distance < min_distance then
        min_distance = distance
        closest_tag  = tag
      end
    end
  end
  return closest_tag
end
function ChartTagUtils.safe_add_chart_tag(force, surface, spec, player, opts)
  if not force or not surface or not spec then
    ErrorHandler.debug_log("Invalid arguments to safe_add_chart_tag", {
      has_force = force ~= nil,
      has_surface = surface ~= nil,
      has_spec = spec ~= nil
    })
    return nil
  end
  if not force.valid then
    ErrorHandler.debug_log("Force is invalid, cannot create chart tag", {
      player_name = player and player.name or "unknown"
    })
    return nil
  end
  if not spec.position or type(spec.position.x) ~= "number" or type(spec.position.y) ~= "number" then
    ErrorHandler.debug_log("Invalid position in chart tag spec", {
      position = spec.position
    })
    return nil
  end
  local surface_index = tonumber(surface.index) or 1
  local gps = GPSUtils.gps_from_map_position(spec.position, surface_index)
  ErrorHandler.debug_log("Attempting to create chart tag", {
    position = spec.position,
    surface_name = surface.name,
    surface_index = surface_index,
    force_name = force.name,
    player_name = player and player.name or "no player",
    has_text = spec.text ~= nil and spec.text ~= "",
    has_icon = spec.icon ~= nil
  })
  local existing_chart_tag = nil
  if player and player.valid and not (opts and opts.skip_collision_check) then
    existing_chart_tag = ChartTagUtils.find_closest_chart_tag_to_position(player, spec.position)
  end
  if existing_chart_tag and existing_chart_tag.valid then
    ErrorHandler.debug_log("Destroying existing chart tag for multiplayer-safe recreation", {
      position = existing_chart_tag.position,
      old_text = existing_chart_tag.text or "",
      old_icon = existing_chart_tag.icon
    })
    local old_gps = GPSUtils.gps_from_map_position(existing_chart_tag.position, surface_index)
    existing_chart_tag.destroy()
    if old_gps then Cache.Lookups.evict_chart_tag_cache_entry(old_gps) end
  end
  local success, result = pcall(function()
    return force.add_chart_tag(surface, spec)
  end)
  if not success then
    ErrorHandler.debug_log("Chart tag creation failed with error", {
      error = result,
      position = spec.position,
      force_name = force and force.name or "unknown",
      force_valid = force and force.valid or false,
      surface_name = surface and surface.name or "unknown",
      surface_valid = surface and surface.valid or false,
      player_name = player and player.name or "unknown"
    })
    return nil
  end
  if not result or not result.valid then
    ErrorHandler.debug_log("Chart tag created but is invalid", {
      chart_tag_exists = result ~= nil,
      position = spec.position
    })
    return nil
  end
  if spec.icon then
    ChartTagUtils.format_icon_as_rich_text(spec.icon)
  end
  return result
end
function ChartTagUtils.format_icon_as_rich_text(icon)
  local ok, result = pcall(function()
    if not icon or type(icon) ~= "table" or not icon.name or type(icon.name) ~= "string" or icon.name == "" then
      return ""
    end
    local icon_type = get_icon_type(icon)
    if type(icon_type) ~= "string" or icon_type == "" then icon_type = "item" end
    if icon_type == "virtual_signal" then icon_type = "virtual-signal" end
    return string.format("[%s=%s]", icon_type, icon.name)
  end)
  if ok and type(result) == "string" then
    return result
  else
    ErrorHandler.warn_log("format_icon_as_rich_text failed, returning blank",
      { icon = icon, error = result })
    return ""
  end
end
function ChartTagUtils.reset_icon_type_lookup()
  icon_type_lookup = {}
end
function ChartTagUtils.build_spec(position, source_chart_tag, player, text)
  local spec = { position = position }
  if text then
    spec.text = text
  elseif source_chart_tag and (type(source_chart_tag) == "userdata" or type(source_chart_tag) == "table") then
    local ok, value = pcall(function() return source_chart_tag.text end)
    spec.text = (ok and type(value) == "string") and value or ""
  else
    spec.text = ""
  end
  if source_chart_tag and (type(source_chart_tag) == "userdata" or type(source_chart_tag) == "table") then
    local ok, icon = pcall(function() return source_chart_tag.icon end)
    if ok and icon and type(icon) == "table" and icon.name and not getmetatable(icon) then
      spec.icon = icon
    end
  end
  return spec
end
function ChartTagUtils.is_admin(player)
  local player_valid, player_error = BasicHelpers.is_valid_player(player)
  if not player_valid then
    ErrorHandler.debug_log("Chart tag edit permission check failed: invalid player", { error = player_error })
    return false
  end
  return player.admin == true
end
function ChartTagUtils.can_edit_chart_tag(player, tag)
  local player_valid = BasicHelpers.is_valid_player(player)
  if not player_valid or not tag then return false, false, false end
  local owner_name = tag.owner_name or ""
  local is_owner = (owner_name ~= "" and player.name == owner_name)
  local is_admin = ChartTagUtils.is_admin(player)
  local can_edit = is_owner or is_admin
  local is_admin_override = (not is_owner) and is_admin
  return can_edit, is_owner, is_admin_override
end
function ChartTagUtils.can_delete_chart_tag(player, tag)
  local player_valid, player_error = BasicHelpers.is_valid_player(player)
  if not player_valid then return false, false, false, "Invalid player: " .. (player_error or "unknown error") end
  if not tag then return false, false, false, "Invalid tag" end
  local is_admin = ChartTagUtils.is_admin(player)
  local owner_name = tag.owner_name or ""
  local is_owner = (owner_name == "" or owner_name == player.name)
  local has_other_favorites = false
  if tag.faved_by_players then
    for k, v in pairs(tag.faved_by_players) do
      local pid = nil
      if type(v) == "number" and v >= 1 then
        pid = v
      elseif type(k) == "number" and k >= 1 and (v == true or v == k) then
        pid = k
      end
      if pid and pid ~= player.index then
        has_other_favorites = true
        break
      end
    end
  end
  local can_delete = (is_owner and not has_other_favorites) or is_admin
  local is_admin_override = is_admin and not (is_owner and not has_other_favorites)
  local reason = nil
  if not can_delete then
    if not is_owner and not is_admin then
      reason = "You are not the owner of this tag and do not have admin privileges"
    elseif is_owner and has_other_favorites and not is_admin then
      reason = "Cannot delete tag: other players have favorited this tag"
    end
  end
  return can_delete, is_owner, is_admin_override, reason
end
function ChartTagUtils.count_faved_player_entries(tag)
  local fbp = tag and tag.faved_by_players
  if not fbp or type(fbp) ~= "table" then return 0 end
  local n = 0
  for k, v in pairs(fbp) do
    local pid = nil
    if type(v) == "number" and v >= 1 then
      pid = v
    elseif type(k) == "number" and k >= 1 and (v == true or v == k) then
      pid = k
    end
    if pid then n = n + 1 end
  end
  return n
end
function ChartTagUtils.log_admin_action(admin_player, action, tag, additional_data)
  local player_valid = BasicHelpers.is_valid_player(admin_player)
  if not player_valid then return end
  local log_data = { admin_name = admin_player.name, action = action, timestamp = game.tick }
  if tag then log_data.tag_owner = tag.owner_name or ""; log_data.tag_gps = tag.gps or "" end
  if additional_data then for k, v in pairs(additional_data) do log_data[k] = v end end
  ErrorHandler.debug_log("Admin action performed", log_data)
end
return ChartTagUtils
