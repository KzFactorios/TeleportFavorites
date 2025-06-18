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
    ErrorHandler.debug_log("Building favorites bar for player during init", { player = player.name })
    fave_bar.build(player)
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

  ErrorHandler.debug_log("Building favorites bar for new player", { player = player.name })
  fave_bar.build(player)
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
  
  ---@diagnostic disable-next-line: param-type-mismatch
  local player = game.get_player(event.player_index)
  if not player or not player.valid then 
    ErrorHandler.debug_log("Tag editor handler: invalid player")
    return 
  end
  
  -- Only handle chart mode interactions
  if player.render_mode ~= defines.render_mode.chart and player.render_mode ~= defines.render_mode.chart_zoomed_in then
    ErrorHandler.debug_log("Tag editor handler: wrong render mode", { 
      render_mode = player.render_mode,
      chart_mode = defines.render_mode.chart,
      chart_zoomed = defines.render_mode.chart_zoomed_in
    })
    return
  end

  -- Check if tag editor is already open - if so, ignore right-click events
  local tag_editor_frame = player.gui.screen[Enum.GuiEnum.GUI_FRAME.TAG_EDITOR]
  if tag_editor_frame and tag_editor_frame.valid then
    -- Tag editor is open, ignore right-click
    return
  end

  -- Get the position we right-clicked upon
  local cursor_position = event.cursor_position
  if not cursor_position or not (cursor_position.x and cursor_position.y) then
    return
  end  -- Normalize the clicked position and convert to GPS string
  ErrorHandler.debug_log("Tag editor: Starting GPS conversion", { cursor_position = cursor_position })
  
  local gps_success, normalized_gps = pcall(GPSUtils.gps_from_map_position, cursor_position, player.surface.index)
  if not gps_success then
    ErrorHandler.warn_log("Tag editor: GPS conversion failed - " .. tostring(normalized_gps))
    return
  end
  
  -- Simple validation - check if position is valid for tagging
  ErrorHandler.debug_log("Tag editor: Starting position validation")
  local pos_valid_success, pos_valid = pcall(PositionUtils.is_valid_tag_position, player, cursor_position)
  if not pos_valid_success then
    ErrorHandler.warn_log("Tag editor: Position validation error - " .. tostring(pos_valid))
    return
  end
  
  if not pos_valid then
    -- Play error sound to indicate invalid position
    GameHelpers.safe_play_sound(player, { path = "utility/cannot_build" })
    ErrorHandler.debug_log("Tag editor: Position validation failed")
    return
  end
    ErrorHandler.debug_log("Tag editor: Position validation passed")
  -- Get normalized position for chart tag creation
  local norm_success, normalized_pos = pcall(PositionUtils.normalize_position, cursor_position)
  if not norm_success then
    ErrorHandler.warn_log("Tag editor: Position normalization failed - " .. tostring(normalized_pos))
    return
  end
  
  local surface_index = player.surface.index
  local gps = GPSUtils.gps_from_map_position(normalized_pos, surface_index)
  
  ErrorHandler.debug_log("Tag editor: Starting cache operations", { gps = gps })
  -- Try to find existing chart tag at this position
  local nrm_chart_tag = ChartTagUtils.find_chart_tag_at_position(player, normalized_pos)
  
  -- Get existing tag from cache if available
  local nrm_tag = Cache.get_tag_by_gps(gps)
  
  -- Check if this is a player favorite
  local nrm_favorite = Cache.is_player_favorite(player, gps)
  
  ErrorHandler.debug_log("Tag editor: Starting settings access")
  -- Get player's teleport radius setting for use in tag editor
  local player_settings = Settings:getPlayerSettings(player)  local search_radius = player_settings.teleport_radius or Constants.settings.TELEPORT_RADIUS_DEFAULT

  ErrorHandler.debug_log("Tag editor: Creating tag data")
  local tag_data = Cache.create_tag_editor_data({
    gps = gps,
    locked = nrm_favorite and nrm_favorite.locked or false,
    is_favorite = nrm_favorite ~= nil,
    icon = nrm_chart_tag and nrm_chart_tag.icon or "",
    text = nrm_chart_tag and nrm_chart_tag.text or "",
    tag = nrm_tag or nil,
    chart_tag = nrm_chart_tag or nil,
    search_radius = search_radius
  })

  ErrorHandler.debug_log("Tag editor: Setting cache data")
  -- Persist GPS in tag_editor_data
  Cache.set_tag_editor_data(player, tag_data)
  
  ErrorHandler.debug_log("Tag editor: Building GUI")
  tag_editor.build(player)
  ErrorHandler.debug_log("Tag editor: Successfully completed")
end

--- Handle chart tag added events
---@param event table Event data for tag addition
function handlers.on_chart_tag_added(event)
  -- Handle automatic tag synchronization when players create chart tags outside of the mod interface
  if not event or not event.tag or not event.tag.valid then return end

  local chart_tag = event.tag
  local player = game.get_player(event.player_index)
  if not player or not player.valid then return end

  -- Check if the chart tag coordinates need normalization
  local position = chart_tag.position
  if not position then return end
  if not basic_helpers.is_whole_number(position.x) or not basic_helpers.is_whole_number(position.y) then
    -- Need to normalize this chart tag to whole numbers
    local position_pair = PositionUtils.create_position_pair(position)    -- Create new chart tag at normalized position using centralized builder
    local chart_tag_spec = ChartTagUtils.build_chart_tag_spec(
      position_pair.new,
      chart_tag,
      player,
      nil,  -- Use existing text from source chart tag
      true  -- Set ownership for final chart tag replacement
      )
      
    local surface_index = chart_tag.surface and chart_tag.surface.index or 1
    local new_chart_tag = ChartTagUtils.safe_add_chart_tag(player.force, chart_tag.surface, chart_tag_spec)
    if new_chart_tag and new_chart_tag.valid then      -- Destroy the old chart tag with fractional coordinates
      chart_tag.destroy()      -- Refresh the cache to include the new chart tag
      Cache.Lookups.invalidate_surface_chart_tags(surface_index)-- Inform the player about the position normalization
      local notification_msg = RichTextFormatter.position_change_notification(
        player,
        new_chart_tag,
        position_pair.old,
        position_pair.new
      )
      GameHelpers.player_print(player, notification_msg)
    end

    -- else, it is possible that something didn't work out (new ct not created)
    -- ignore this occurrence for now

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
      chart_tag_last_user = event.tag.last_user or "",
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
  local new_chart_tag = Cache.Lookups.get_chart_tag_by_gps(new_gps)  -- Ensure new chart tag exists
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
---@param old_gps string|nil Original GPS coordinate string
---@param new_gps string|nil New GPS coordinate string
---@param acting_player LuaPlayer|nil Player who initiated the change
local function update_favorites_gps(old_gps, new_gps, acting_player)
  if not old_gps or not new_gps then return end

  local acting_player_index = acting_player and acting_player.valid and acting_player.index or nil

  -- Use PlayerFavorites method to handle GPS updates properly
  local PlayerFavorites = require("core.favorite.player_favorites")
  local affected_players = PlayerFavorites.update_gps_for_all_players(old_gps, new_gps, acting_player_index)

  -- Notify affected players about their favorite location changes
  if #affected_players > 0 then
    local old_position = GPSUtils.map_position_from_gps(old_gps)
    local new_position = GPSUtils.map_position_from_gps(new_gps)

    -- Extract surface_index from the GPS string
    local surface_index = 1
    local parts = {}
    for part in string.gmatch(old_gps, "[^.]+") do
      table.insert(parts, part)
    end
    if #parts >= 3 then
      surface_index = tonumber(parts[3]) or 1
    end    -- Get chart tag for better notification
    local chart_tag = Cache.Lookups.get_chart_tag_by_gps(new_gps)for _, affected_player in ipairs(affected_players) do
      if affected_player and affected_player.valid then
        local position_msg = RichTextFormatter.position_change_notification(
          affected_player,
          chart_tag,
          old_position or { x = 0, y = 0 },
          new_position or { x = 0, y = 0 }
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
    local position = chart_tag.position    -- Ensure coordinates are whole numbers
    if PositionUtils.needs_normalization(position) then
      local position_pair = PositionUtils.create_position_pair(position)
      -- Create new chart tag with normalized position
      local surface = chart_tag.surface      -- Create chart tag spec using centralized builder
      local chart_tag_spec = ChartTagUtils.build_chart_tag_spec(
        position_pair.new,
        chart_tag,
        player,
        nil,  -- Use existing text from source chart tag
        true  -- Set ownership for final chart tag replacement
      )

      local new_chart_tag = ChartTagUtils.safe_add_chart_tag(player.force, surface, chart_tag_spec)
      if new_chart_tag and new_chart_tag.valid then
        -- Destroy the old chart tag with fractional coordinates
        chart_tag.destroy()

        -- Update the tag and gps
        local surface_index = surface and surface.index or 1

        -- Use the position_pair for consistent position references        local old_position = position_pair.old
        local new_position = position_pair.new        -- Create new GPS from normalized position
        new_gps = GPSUtils.gps_from_map_position(new_position, surface_index)        -- Refresh the cache
        Cache.Lookups.invalidate_surface_chart_tags(surface_index)

        -- Update chart_tag reference for future operations
        chart_tag = new_chart_tag        -- Notify the player about the normalization
        local notification_msg = RichTextFormatter.position_change_notification(
          player,
          new_chart_tag,
          old_position,
          new_position
        )
        GameHelpers.player_print(player, notification_msg)
      end
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
  if not event or not event.tag or not event.tag.valid then return end  local chart_tag = event.tag
  local surface_index = (chart_tag.surface and chart_tag.surface.index) or 1
  local gps = GPSUtils.gps_from_map_position(chart_tag.position, surface_index)

  -- Get the player who is removing the chart tag
  local tag = Cache.get_tag_by_gps(gps)
  local player = game.get_player(event.player_index)  -- Check if this tag has favorites from other players
  if tag and tag.faved_by_players and #tag.faved_by_players > 0 then    if not player or not player.valid then      -- No valid player to handle the removal, just clear the cache
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
    local can_delete, is_owner, is_admin_override = AdminUtils.can_delete_chart_tag(player, chart_tag, tag)
    
    -- If deletion is not allowed (non-admin and other players have favorites), prevent it
    if has_other_players_favorites and not can_delete then
      -- Recreate the chart tag since it was already removed by the event      -- Create chart tag spec using centralized builder
      local chart_tag_spec = ChartTagUtils.build_chart_tag_spec(chart_tag.position, chart_tag, player, nil, true)

      local new_chart_tag = ChartTagUtils.safe_add_chart_tag(player.force, chart_tag.surface, chart_tag_spec)

      if new_chart_tag and new_chart_tag.valid then        -- Update the tag with the new chart tag reference        tag.chart_tag = new_chart_tag
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

--- Handles Ctrl+Shift+Right-click to display tile debugging information
---@param event table Event data containing player_index and cursor_position
function handlers.on_debug_tile_info_custom_input(event)
  -- Debug logging using ErrorHandler
  ErrorHandler.debug_log("Debug tile info handler called", {
    player_index = event.player_index,
    has_cursor_position = event.cursor_position ~= nil
  })

  local player = game.get_player(event.player_index)
  if not player or not player.valid then
    ErrorHandler.debug_log("Invalid player in debug tile info", {
      player_index = event.player_index
    })
    return
  end

  -- Check if cursor position is available
  if not event.cursor_position then
    GameHelpers.player_print(player, "[TF Debug] No cursor position available")
    ErrorHandler.debug_log("No cursor position in debug tile info event")
    return
  end
  local pos = event.cursor_position
  local surface = player.surface

  -- Get tile at position
  local tile = surface.get_tile(pos.x, pos.y)
  if not tile then
    GameHelpers.player_print(player, "[TF Debug] No tile found at position")
    return
  end

  -- Gather comprehensive tile information
  local tile_name = tile.name or "unknown"
  local tile_prototype = tile.prototype

  -- Create debug information string
  local debug_info = {}
  table.insert(debug_info, "=== TILE DEBUG INFO ===")
  table.insert(debug_info, "Position: " .. string.format("%.2f", pos.x) .. ", " .. string.format("%.2f", pos.y))
  table.insert(debug_info, "Tile name: " .. tile_name)

  -- Get tile prototype information if available
  if tile_prototype then
    local walking_speed = tile_prototype.walking_speed_modifier or 1.0
    table.insert(debug_info, "Walking speed modifier: " .. string.format("%.2f", walking_speed))

    if tile_prototype.layer then
      table.insert(debug_info, "Tile layer: " .. tile_prototype.layer)
    end

    if tile_prototype.collision_mask then
      local collision_layers = {}
      for layer_name, enabled in pairs(tile_prototype.collision_mask.layers) do
        if enabled then
          table.insert(collision_layers, layer_name)
        end
      end
      if #collision_layers > 0 then
        table.insert(debug_info, "Collision layers: " .. table.concat(collision_layers, ", "))
      else
        table.insert(debug_info, "Collision layers: none")
      end
    end
  end
  -- Test walkability using our enhanced function
  local is_walkable = PositionUtils.is_walkable_position(surface, pos)
  table.insert(debug_info, "Is walkable (comprehensive): " .. tostring(is_walkable))

  -- Test individual checks
  local is_water = PositionUtils.is_water_tile(surface, pos)
  table.insert(debug_info, "Is water tile: " .. tostring(is_water))

  local is_space = PositionUtils.is_space_tile(surface, pos)
  table.insert(debug_info, "Is space tile: " .. tostring(is_space))
  -- Test pathfinding
  local pathfind_pos = surface:find_non_colliding_position("character", pos, 0, 0.1)
  if pathfind_pos then
    local dx = math.abs(pathfind_pos.x - pos.x)
    local dy = math.abs(pathfind_pos.y - pos.y)
    local distance = math.sqrt(dx * dx + dy * dy)
    table.insert(debug_info, "Pathfinding result: " .. string.format("%.3f", pathfind_pos.x) ..
      ", " .. string.format("%.3f", pathfind_pos.y))
    table.insert(debug_info, "Distance from original: " .. string.format("%.3f", distance))
    table.insert(debug_info, "Pathfinding says walkable: " .. tostring(distance < 0.1))
  else
    table.insert(debug_info, "Pathfinding result: No valid position found")
  end
  -- Test position validation
  -- skip notification
  local is_valid_pos = PositionUtils.is_valid_tag_position(player, pos, true)
  table.insert(debug_info, "Valid for tagging: " .. tostring(is_valid_pos))

  -- Check for nearby chart tags
  local nearest_chart_tag = GameHelpers.get_nearest_chart_tag_to_click_position(player, pos, 5.0)
  if nearest_chart_tag then
    local tag_distance = math.sqrt((nearest_chart_tag.position.x - pos.x) ^ 2 + (nearest_chart_tag.position.y - pos.y) ^
    2)
    table.insert(debug_info, "Nearest chart tag: " .. string.format("%.2f", tag_distance) .. " tiles away")
    if nearest_chart_tag.text and nearest_chart_tag.text ~= "" then
      table.insert(debug_info, "Tag text: " .. nearest_chart_tag.text)
    end
  else
    table.insert(debug_info, "No chart tags nearby")
  end

  table.insert(debug_info, "=======================")
  -- Print all debug information
  for _, line in ipairs(debug_info) do
    GameHelpers.player_print(player, line)
  end
end

return handlers
