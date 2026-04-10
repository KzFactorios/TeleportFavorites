---@diagnostic disable: undefined-global

-- core/utils/chart_tag_utils.lua
-- TeleportFavorites Factorio Mod
-- Unified chart tag utilities for all chart tag operations.
-- Provides multiplayer-safe helpers for chart tag detection, cache management, and safe creation.
-- Integrates with GPSUtils, ErrorHandler, and Cache for robust surface-aware operations.
--
-- CRITICAL MULTIPLAYER SAFETY:
-- Chart tags MUST be created/destroyed via game actions, never directly modified.
-- Direct property assignment (chart_tag.text = "foo") causes desync in multiplayer.
-- This module uses destroy-and-recreate pattern for all chart tag updates.
--
-- API:
--   ChartTagUtils.find_closest_chart_tag_to_position(player, cursor_position): Find chart tag at a position.
--   ChartTagUtils.safe_add_chart_tag(force, surface, spec, player): Safely create or update a chart tag.

local Deps = require("deps")
local BasicHelpers, ErrorHandler, Cache, GPSUtils =
  Deps.BasicHelpers, Deps.ErrorHandler, Deps.Cache, Deps.GpsUtils

-- ===========================
-- ICON TYPING (from icon_typing.lua)
-- ===========================

--- Non-persistent O(1) lookup table: icon name -> type
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

---@class ChartTagUtils
local ChartTagUtils = {}

--- Find chart tag at a specific position using a bounded area query.
--- Replaces the former full-surface scan: Factorio's spatial index returns only tags
--- within the bounding box, so this is O(tags in box) instead of O(all tags on surface).
---@param player LuaPlayer Player context
---@param cursor_position MapPosition Position to check
---@return LuaCustomChartTag? chart_tag Found chart tag or nil
function ChartTagUtils.find_closest_chart_tag_to_position(player, cursor_position)
  if not BasicHelpers.is_valid_player(player) or not cursor_position then return nil end

  -- MULTIPLAYER FIX: render_mode is client-specific and causes desyncs.
  -- Removed render_mode gate from this data lookup function.
  -- Caller is responsible for context validation (event handlers, UI layer).
  local surface = player.surface
  if not surface or not surface.valid then return nil end

  local click_radius = Cache.Settings.get_chart_tag_click_radius()

  -- Single bounded area query: Factorio's spatial index does the filtering.
  -- Only tags within the click_radius box are returned, avoiding a full-surface scan.
  local area_tags = game.forces["player"].find_chart_tags(surface, {
    left_top     = { x = cursor_position.x - click_radius, y = cursor_position.y - click_radius },
    right_bottom = { x = cursor_position.x + click_radius, y = cursor_position.y + click_radius },
  })

  if not area_tags or #area_tags == 0 then return nil end

  -- Among the returned tags, pick the one with minimum Euclidean distance.
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

--- Safe wrapper for chart tag creation with comprehensive error handling and collision detection.
---@param force LuaForce The force that will own the chart tag
---@param surface LuaSurface The surface where the tag will be placed
---@param spec table Chart tag specification table (position, text, etc.)
---@param player LuaPlayer? Player context for collision notifications
---@param opts table|nil Optional flags: { skip_collision_check = bool }
---   skip_collision_check: when true, skips the find_chart_tags area query.
---   Use this from tag-editor confirm paths where the position is pre-validated and
---   any existing tag was already destroyed before this call.
---@return LuaCustomChartTag|nil chart_tag The created chart tag or nil if failed
function ChartTagUtils.safe_add_chart_tag(force, surface, spec, player, opts)
  -- Input validation
  if not force or not surface or not spec then
    ErrorHandler.debug_log("Invalid arguments to safe_add_chart_tag", {
      has_force = force ~= nil,
      has_surface = surface ~= nil,
      has_spec = spec ~= nil
    })
    return nil
  end

  -- Validate force has valid state and can create chart tags
  if not force.valid then
    ErrorHandler.debug_log("Force is invalid, cannot create chart tag", {
      player_name = player and player.name or "unknown"
    })
    return nil
  end

  -- Validate position
  if not spec.position or type(spec.position.x) ~= "number" or type(spec.position.y) ~= "number" then
    ErrorHandler.debug_log("Invalid position in chart tag spec", {
      position = spec.position
    })
    return nil
  end
  -- Natural position system: check for existing chart tag via cache
  local surface_index = tonumber(surface.index) or 1
  local gps = GPSUtils.gps_from_map_position(spec.position, surface_index)
  
  -- Log chart tag creation attempt for debugging
  ErrorHandler.debug_log("Attempting to create chart tag", {
    position = spec.position,
    surface_name = surface.name,
    surface_index = surface_index,
    force_name = force.name,
    player_name = player and player.name or "no player",
    has_text = spec.text ~= nil and spec.text ~= "",
    has_icon = spec.icon ~= nil
  })
  
  -- Collision check: find any existing tag at the target position and destroy it first.
  -- Skipped when the caller has already handled this (e.g. tag-editor confirm path
  -- where the old tag was destroyed before this call, saving a find_chart_tags API call).
  local existing_chart_tag = nil
  if player and player.valid and not (opts and opts.skip_collision_check) then
    existing_chart_tag = ChartTagUtils.find_closest_chart_tag_to_position(player, spec.position)
  end

  if existing_chart_tag and existing_chart_tag.valid then
    -- MULTIPLAYER FIX: Destroy and recreate instead of direct modification
    -- Direct property assignment causes desync in multiplayer
    ErrorHandler.debug_log("Destroying existing chart tag for multiplayer-safe recreation", {
      position = existing_chart_tag.position,
      old_text = existing_chart_tag.text or "",
      old_icon = existing_chart_tag.icon
    })

    local old_gps = GPSUtils.gps_from_map_position(existing_chart_tag.position, surface_index)
    existing_chart_tag.destroy()
    -- Surgical eviction: this GPS entry now refers to a destroyed tag.
    if old_gps then Cache.Lookups.evict_chart_tag_cache_entry(old_gps) end

    -- Fall through to create new chart tag with updated properties
    -- (the force.add_chart_tag call below will create it)
  end

  -- Use protected call to catch any errors
  local success, result = pcall(function()
    return force.add_chart_tag(surface, spec)
  end)

  -- Check if creation was successful
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

  -- Cast result to ensure proper typing after successful pcall
  ---@cast result LuaCustomChartTag
  -- Validate the created chart tag
  if not result or not result.valid then
    ErrorHandler.debug_log("Chart tag created but is invalid", {
      chart_tag_exists = result ~= nil,
      position = spec.position
    })
    return nil
  end

  -- Register the icon in icon_type_lookup for O(1) lookup
  if spec.icon then
    ChartTagUtils.format_icon_as_rich_text(spec.icon)
  end

  return result
end

-- ===========================
-- ICON FORMATTING (was icon_typing.lua public API)
-- ===========================

--- Formats an icon object into Factorio rich text for display in GUIs
---@param icon table { name: string, type?: string }
---@return string
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

--- Erases all entries in the icon_type_lookup table (non-persistent)
function ChartTagUtils.reset_icon_type_lookup()
  icon_type_lookup = {}
end

-- ===========================
-- CHART TAG SPEC BUILDER (from chart_tag_spec_builder.lua)
-- ===========================

--- Build a chart tag spec table for use with force.add_chart_tag
---@param position MapPosition
---@param source_chart_tag LuaCustomChartTag|table|nil
---@param player LuaPlayer|nil
---@param text string|nil Custom text override
---@return table chart_tag_spec
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

-- ===========================
-- ADMIN UTILS (from admin_utils.lua)
-- ===========================

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
    for _, player_index in ipairs(tag.faved_by_players) do
      if player_index ~= player.index then
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

function ChartTagUtils.log_admin_action(admin_player, action, tag, additional_data)
  local player_valid = BasicHelpers.is_valid_player(admin_player)
  if not player_valid then return end
  local log_data = { admin_name = admin_player.name, action = action, timestamp = game.tick }
  if tag then log_data.tag_owner = tag.owner_name or ""; log_data.tag_gps = tag.gps or "" end
  if additional_data then for k, v in pairs(additional_data) do log_data[k] = v end end
  ErrorHandler.debug_log("Admin action performed", log_data)
end

return ChartTagUtils
