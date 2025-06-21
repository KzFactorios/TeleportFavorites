-- filepath: v:\Fac2orios\2_Gemini\mods\TeleportFavorites\core\events\handlers.lua
--[[
core/events/handlers.lua
TeleportFavorites Factorio Mod
-----------------------------
Centralized event handler implementations for TeleportFavorites.

Features:
- Handles Factorio events for tag creation, modification, removal, and player actions
- Ensures robust multiplayer and surface-aware updates to tags, chart tags, and player favorites
- Uses helpers for tag destruction, GPS conversion, and cache management
- All event logic is routed through this module for maintainability and separation of concerns
- Comprehensive error handling and validation for all event types
- Type-safe player retrieval and validation

Architecture:
- Event handlers are pure functions that receive event objects
- All handlers validate inputs and handle edge cases gracefully
- Player objects are properly null-checked to prevent runtime errors
- GPS position normalization is handled through centralized helpers
- Surface and multi-player compatibility is maintained throughout

API:
-----
-- Mod initialization logic
- handlers.on_init()
-- Runtime-only structure re-initialization
- handlers.on_load()
-- New player initialization
- handlers.on_player_created(event)
-- Ensures surface cache for player after surface change
- handlers.on_player_changed_surface(event)
-- Handles right-click chart tag editor opening
- handlers.on_open_tag_editor_custom_input(event)
-- Teleports player to favorite location
-- Handles chart tag creation (stub)
- handlers.on_chart_tag_added(event)
-- Handles chart tag modification, GPS and favorite updates
- handlers.on_chart_tag_modified(event)
-- Handles chart tag removal and cleanup
- handlers.on_chart_tag_removed(event)

--]]

---@diagnostic disable: undefined-global

-- core/events/handlers.lua
-- Centralized event handler implementations for TeleportFavorites

local Cache = require("core.cache.cache")
local ChartTagUtils = require("core.utils.chart_tag_utils")
local Constants = require("constants")
local Enum = require("prototypes.enums.enum")
local ErrorHandler = require("core.utils.error_handler")
local fave_bar = require("gui.favorites_bar.fave_bar")
local GameHelpers = require("core.utils.game_helpers")
local basic_helpers = require("core.utils.basic_helpers")
local GPSUtils = require("core.utils.gps_utils")
local PositionUtils = require("core.utils.position_utils")
local RichTextFormatter = require("core.utils.rich_text_formatter")
local Settings = require("core.utils.settings_access")
local Tag = require("core.tag.tag")
local tag_destroy_helper = require("core.tag.tag_destroy_helper")
local tag_editor = require("gui.tag_editor.tag_editor")
local AdminUtils = require("core.utils.admin_utils")
local ChartTagOwnershipManager = require("core.control.chart_tag_ownership_manager")


local handlers = {}

function handlers.on_init()
  ErrorHandler.debug_log("Mod initialization started")

  -- Clean up orphaned chart tag ownership from players who removed the mod
  local orphaned_count = ChartTagOwnershipManager.reset_orphaned_ownership()
  if orphaned_count > 0 then
    ErrorHandler.debug_log("Cleaned up orphaned chart tag ownership during init", {
      orphaned_count = orphaned_count
    })
  end

  for _, player in pairs(game.players) do
    -- Only register GUI observers; let observer trigger the initial bar build
    local ok, gui_observer = pcall(require, "core.pattern.gui_observer")
    if ok and gui_observer and gui_observer.GuiEventBus and gui_observer.GuiEventBus.register_player_observers then
      gui_observer.GuiEventBus.register_player_observers(player)
    end
  end
  ErrorHandler.debug_log("Mod initialization completed")
end

function handlers.on_load()
  -- Re-initialize runtime-only structures if needed
end

function handlers.on_player_created(event)
  ErrorHandler.debug_log("New player created", { player_index = event.player_index })
  ---@diagnostic disable-next-line: param-type-mismatch
  local player = game.get_player(event.player_index)
  if not player or not player.valid then
    ErrorHandler.debug_log("Player creation handler: invalid player")
    return
  end

  -- Only register GUI observers; let observer trigger the initial bar build
  local ok, gui_observer = pcall(require, "core.pattern.gui_observer")
  if ok and gui_observer and gui_observer.GuiEventBus and gui_observer.GuiEventBus.register_player_observers then
    gui_observer.GuiEventBus.register_player_observers(player)
  end
end

function handlers.on_player_changed_surface(event)
  ---@diagnostic disable-next-line: param-type-mismatch
  local player = game.get_player(event.player_index)
  if not player or not player.valid then return end

  fave_bar.build(player)
end

--- Handles right-click on the chart view to open tag editor
---@param event table Event data containing player_index and cursor_position
function handlers.on_open_tag_editor_custom_input(event)
  ErrorHandler.debug_log("Tag editor custom input handler called", {
    player_index = event.player_index,
    cursor_position = event.cursor_position
  })

  local player = game.get_player(event.player_index)
  if not player or not player.valid then
    ErrorHandler.debug_log("Tag editor handler: invalid player")
    return
  end

  if player.render_mode ~= defines.render_mode.chart and player.render_mode ~= defines.render_mode.chart_zoomed_in then
    ErrorHandler.debug_log("Tag editor handler: wrong render mode", {
      render_mode = player.render_mode,
      chart_mode = defines.render_mode.chart,
      chart_zoomed = defines.render_mode.chart_zoomed_in
    })
    return
  end

  local tag_editor_frame = player.gui.screen[Enum.GuiEnum.GUI_FRAME.TAG_EDITOR]
  if tag_editor_frame and tag_editor_frame.valid then
    return
  end

  local cursor_position = event.cursor_position
  if not cursor_position or not (cursor_position.x and cursor_position.y) then
    return
  end
  ErrorHandler.debug_log("Tag editor: Starting GPS conversion", { cursor_position = cursor_position })

  -- Utility: Find or create tag_data for tag editor (was in on_open_tag_editor_custom_input)
  local function find_or_create_tag_data(player, cursor_position)
    local surface_index = player.surface.index
    local normalized_pos = PositionUtils.normalize_position(cursor_position)
    local gps = GPSUtils.gps_from_map_position(normalized_pos, surface_index)
    local nrm_tag = Cache.get_tag_by_gps(gps)
    local nrm_chart_tag = nrm_tag and nrm_tag.chart_tag or nil
    local click_radius = Constants.settings.CHART_TAG_CLICK_RADIUS or 1

    -- Search for nearby chart tags if no tag match
    if not nrm_tag then
      local force_tags = Cache.Lookups.get_chart_tag_cache(surface_index)
      local min_distance = click_radius
      for _, tag in pairs(force_tags) do
        if tag and tag.valid then
          local dx = math.abs(tag.position.x - normalized_pos.x)
          local dy = math.abs(tag.position.y - normalized_pos.y)
          if dx <= click_radius and dy <= click_radius then
            local distance = math.sqrt(dx * dx + dy * dy)
            if distance < min_distance then
              min_distance = distance
              nrm_chart_tag = tag
            end
          end
        end
      end
      if nrm_chart_tag then
        gps = GPSUtils.gps_from_map_position(nrm_chart_tag.position, surface_index)
        nrm_tag = Cache.get_tag_by_gps(gps)
      end
    end

    local tag_gps = gps
    -- Create temp chart tag if still no match
    if not nrm_tag and not nrm_chart_tag then
      local temp_spec = ChartTagUtils.build_chart_tag_spec(normalized_pos, nil, player, nil, false)
      local tmp_chart_tag = ChartTagUtils.safe_add_chart_tag(player.force, player.surface, temp_spec, player)
      if tmp_chart_tag and tmp_chart_tag.valid then
        tag_gps = GPSUtils.gps_from_map_position(tmp_chart_tag.position, surface_index)
        tag_destroy_helper.destroy_tag_and_chart_tag(nil, tmp_chart_tag)
      end
    end
    if nrm_tag then
      tag_gps = nrm_tag.gps
      nrm_chart_tag = nrm_tag.chart_tag
    elseif nrm_chart_tag then
      tag_gps = GPSUtils.gps_from_map_position(nrm_chart_tag.position, surface_index)
    end
    local nrm_favorite = Cache.is_player_favorite(player, tag_gps)
    local tag_text = nrm_chart_tag and nrm_chart_tag.text or ""
    local tag_icon = nrm_chart_tag and nrm_chart_tag.icon or nil
    return Cache.create_tag_editor_data({
      gps = tag_gps,
      locked = nrm_favorite and nrm_favorite.locked or false,
      is_favorite = nrm_favorite ~= nil,
      icon = tag_icon,
      text = tag_text,
      tag = nrm_tag or nil,
      chart_tag = nrm_chart_tag or nil,
      search_radius = click_radius
    })
  end

  -- Use helper for tag lookup and tag_data creation
  local tag_data = find_or_create_tag_data(player, cursor_position)
  Cache.set_tag_editor_data(player, tag_data)
  tag_editor.build(player)
  ErrorHandler.debug_log("Tag editor: Successfully completed")
end

-- Utility: Normalize and replace chart tag (was duplicated in on_chart_tag_added/on_chart_tag_modified)
local function normalize_and_replace_chart_tag(chart_tag, player)
  local position = chart_tag.position
  if not position then return end
  if not basic_helpers.is_whole_number(position.x) or not basic_helpers.is_whole_number(position.y) then
    local position_pair = PositionUtils.create_position_pair(position)
    local chart_tag_spec = ChartTagUtils.build_chart_tag_spec(
      position_pair.new,
      chart_tag,
      player,
      nil,
      true
    )
    local surface_index = chart_tag.surface and chart_tag.surface.index or 1
    local new_chart_tag = ChartTagUtils.safe_add_chart_tag(player and player.force or chart_tag.force, chart_tag.surface, chart_tag_spec, player)
    if new_chart_tag and new_chart_tag.valid then
      chart_tag.destroy()
      Cache.Lookups.invalidate_surface_chart_tags(surface_index)
      return new_chart_tag, position_pair
    end
  end
  return nil, nil
end

--- Handle chart tag added events
---@param event table Event data for tag addition
function handlers.on_chart_tag_added(event)
  -- Handle automatic tag synchronization when players create chart tags outside of the mod interface
  if not event or not event.tag or not event.tag.valid then return end

  local chart_tag = event.tag
  local player = nil
  if event.player_index then
    player = game.get_player(event.player_index)
    if not player or not player.valid then player = nil end
  end

  -- Check if the chart tag coordinates need normalization
  local new_chart_tag, position_pair = normalize_and_replace_chart_tag(chart_tag, player)
  if new_chart_tag then
    -- Defensive: player is always nil here due to prior logic, so skip notification
    -- (This avoids the impossible 'if player and player.valid' error)
    -- No-op
  end
end

--- Validate if a tag modification event is valid
---@param event table Chart tag modification event
---@param player LuaPlayer|nil Player who triggered the modification
---@return boolean valid True if modification should be processed
local function is_valid_tag_modification(event, player)
  if not player or not player.valid then return false end
  if not event.tag or not event.tag.valid then return false end

  -- Check permissions using AdminUtils
  local can_edit, is_owner, is_admin_override = AdminUtils.can_edit_chart_tag(player, event.tag)

  if not can_edit then
    ErrorHandler.debug_log("Chart tag modification rejected: insufficient permissions", {
      player_name = player.name,
      chart_tag_last_user = event.tag.last_user and event.tag.last_user.name or "",
      is_admin = AdminUtils.is_admin(player)
    })
    return false
  end

  -- Log admin action if this is an admin override
  if is_admin_override then
    AdminUtils.log_admin_action(player, "modify_chart_tag", event.tag, {
      modification_type = "external_edit"
    })
  end

  -- Transfer ownership to admin if last_user is unspecified
  AdminUtils.transfer_ownership_to_admin(event.tag, player)

  return true
end

--- Extract GPS coordinates from tag modification event
---@param event table Chart tag modification event
---@param player LuaPlayer|nil Player context for surface fallbacks
---@return string|nil new_gps New GPS coordinate string
---@return string|nil old_gps Old GPS coordinate string
local function extract_gps(event, player)
  local new_gps = nil
  local old_gps = nil
  if event.tag and event.tag.position and player then
    local surface_index = (event.tag.surface and event.tag.surface.index) or player.surface.index
    new_gps = GPSUtils.gps_from_map_position(event.tag.position, surface_index)
  end

  if event.old_position and player then
    local surface_index = (event.old_surface and event.old_surface.index) or player.surface.index
    old_gps = GPSUtils.gps_from_map_position(event.old_position, surface_index)
  end

  return new_gps, old_gps
end

--- Update tag data and cleanup old chart tag
---@param old_gps string|nil Original GPS coordinate string
---@param new_gps string|nil New GPS coordinate string
---@param event table Chart tag modification event
---@param player LuaPlayer|nil Player context
local function update_tag_and_cleanup(old_gps, new_gps, event, player)
  if not old_gps or not new_gps then return end
  local old_chart_tag = Cache.Lookups.get_chart_tag_by_gps(old_gps)
  local new_chart_tag = Cache.Lookups.get_chart_tag_by_gps(new_gps) -- Ensure new chart tag exists
  if not new_chart_tag and player then
    local surface_index = (event.tag.surface and event.tag.surface.index) or player.surface.index
    Cache.Lookups.invalidate_surface_chart_tags(surface_index)
    new_chart_tag = Cache.Lookups.get_chart_tag_by_gps(new_gps)
    if not new_chart_tag then
      error("[TeleportFavorites] Failed to find or create new chart tag after modification.")
    end
  end

  -- Get or create tag object
  local old_tag = Cache.get_tag_by_gps(old_gps)
  if not old_tag then
    old_tag = Tag.new(new_gps, {})
  end

  -- Update tag with new coordinates and chart tag reference
  old_tag.gps = new_gps
  old_tag.chart_tag = new_chart_tag

  -- Clean up old chart tag if it exists and is different from new one
  if old_chart_tag and old_chart_tag.valid and old_chart_tag ~= new_chart_tag then
    tag_destroy_helper.destroy_tag_and_chart_tag(nil, old_chart_tag)
  end
end

--- Update all player favorites that reference the old GPS to use new GPS and notify affected players
local function update_favorites_gps(old_gps, new_gps, acting_player)
  if not old_gps or not new_gps then return end
  local acting_player_index = acting_player and acting_player.valid and acting_player.index or nil
  local PlayerFavorites = require("core.favorite.player_favorites")
  local affected_players = PlayerFavorites.update_gps_for_all_players(old_gps, new_gps, acting_player_index)
  if #affected_players > 0 then
    local old_position = GPSUtils.map_position_from_gps(old_gps)
    local new_position = GPSUtils.map_position_from_gps(new_gps)
    local surface_index = 1
    local parts = {}
    for part in string.gmatch(old_gps, "[^.]+") do table.insert(parts, part) end
    if #parts >= 3 then surface_index = tonumber(parts[3]) or 1 end
    local chart_tag = Cache.Lookups.get_chart_tag_by_gps(new_gps)
    for _, affected_player in ipairs(affected_players) do
      if affected_player and affected_player.valid then
        local position_msg = RichTextFormatter.position_change_notification(
          affected_player, chart_tag, old_position or { x = 0, y = 0 }, new_position or { x = 0, y = 0 }
        )
        GameHelpers.player_print(affected_player, position_msg)
      end
    end
  end
end

--- Handle chart tag modification events
---@param event table Chart tag modification event data
function handlers.on_chart_tag_modified(event)
  local player = game.get_player(event.player_index)
  if not player or not player.valid then return end

  if not is_valid_tag_modification(event, player) then return end

  local new_gps, old_gps = extract_gps(event, player)

  -- Check for need to normalize coordinates
  local chart_tag = event.tag
  ---@cast player LuaPlayer
  if chart_tag and chart_tag.valid and chart_tag.position and player and player.valid then
    local new_chart_tag, position_pair = normalize_and_replace_chart_tag(chart_tag, player)
    if new_chart_tag then
      -- Destroy the old chart tag with fractional coordinates is handled in helper
      -- Update the tag and gps
      local surface_index = chart_tag.surface and chart_tag.surface.index or 1
      local new_position = position_pair and position_pair.new or chart_tag.position
      new_gps = GPSUtils.gps_from_map_position(new_position, surface_index)
      Cache.Lookups.invalidate_surface_chart_tags(surface_index)
      -- Update chart_tag reference for future operations
      chart_tag = new_chart_tag
      local notification_msg = RichTextFormatter.position_change_notification(
        player,
        new_chart_tag,
        old_gps and GPSUtils.map_position_from_gps(old_gps) or {},
        new_position
      )
      GameHelpers.player_print(player, notification_msg)
    end
  end

  update_tag_and_cleanup(old_gps, new_gps, event, player)

  -- Update favorites GPS and notify affected players
  if old_gps and new_gps and old_gps ~= new_gps then
    update_favorites_gps(old_gps, new_gps, player)
  end
end

--- Handle chart tag removal events
---@param event table Chart tag removal event data
function handlers.on_chart_tag_removed(event)
  if not event or not event.tag or not event.tag.valid then return end
  local chart_tag = event.tag

  -- short circuit if there is no text or icon - it is not a valid MOD tag
  if chart_tag and not chart_tag.icon and (not chart_tag.text or chart_tag.text == "") then return end

  local surface_index = (chart_tag.surface and chart_tag.surface.index) or 1
  local gps = GPSUtils.gps_from_map_position(chart_tag.position, surface_index)

  -- Get the player who is removing the chart tag
  local tag = Cache.get_tag_by_gps(gps)
  local player = game.get_player(event.player_index)                                                           -- Check if this tag has favorites from other players
  if tag and tag.faved_by_players and #tag.faved_by_players > 0 then
    if not player or not player.valid then                                                                     -- No valid player to handle the removal, just clear the cache
      Cache.Lookups.invalidate_surface_chart_tags(surface_index)
      return
    end
    ---@cast tag -nil
    -- Check if any favorites belong to other players
    local has_other_players_favorites = false

    for _, fav_player_index in ipairs(tag.faved_by_players) do
      local fav_player = game.get_player(fav_player_index)
      if fav_player and fav_player.valid and fav_player.name ~= player.name then
        has_other_players_favorites = true
        break
      end
    end

    -- Use AdminUtils to check if deletion should be prevented
    local can_delete, _is_owner, is_admin_override = AdminUtils.can_delete_chart_tag(player, chart_tag, tag)

    -- If deletion is not allowed (non-admin and other players have favorites), prevent it
    if has_other_players_favorites and not can_delete then
      -- Recreate the chart tag since it was already removed by the event      -- Create chart tag spec using centralized builder
      local chart_tag_spec = ChartTagUtils.build_chart_tag_spec(chart_tag.position, chart_tag, player, nil, true)

      local new_chart_tag = ChartTagUtils.safe_add_chart_tag(player.force, chart_tag.surface, chart_tag_spec, player)

      if new_chart_tag and new_chart_tag.valid then -- Update the tag with the new chart tag reference        tag.chart_tag = new_chart_tag
        -- Refresh the cache
        Cache.Lookups.invalidate_surface_chart_tags(surface_index)
        -- Notify the player
        local deletion_msg = RichTextFormatter.deletion_prevention_notification(new_chart_tag)
        GameHelpers.player_print(player, deletion_msg)
        return
      end
    elseif is_admin_override then
      -- Log admin action for forced deletion
      AdminUtils.log_admin_action(player, "force_delete_chart_tag", chart_tag, {
        had_other_favorites = has_other_players_favorites,
        override_reason = "admin_privileges"
      })
    end
  end

  -- Only destroy if the chart tag is not already being destroyed by our helper
  if not tag_destroy_helper.is_chart_tag_being_destroyed(chart_tag) then
    tag_destroy_helper.destroy_tag_and_chart_tag(tag, chart_tag)
  end
end

return handlers
