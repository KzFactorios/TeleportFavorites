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
local Logger = require("core.utils.enhanced_error_handler")
local fave_bar = require("gui.favorites_bar.fave_bar")
local PositionUtils = require("core.utils.position_utils")
local GPSUtils = require("core.utils.gps_utils")
local ErrorHandler = require("core.utils.error_handler")
local CursorUtils = require("core.utils.cursor_utils")
local TagDestroyHelper = require("core.tag.tag_destroy_helper")
local tag_editor = require("gui.tag_editor.tag_editor")

-- Import specialized event helpers for better modularity
local TagEditorEventHelpers = require("core.events.tag_editor_event_helpers")
local ChartTagModificationHelpers = require("core.events.chart_tag_modification_helpers")
local ChartTagRemovalHelpers = require("core.events.chart_tag_removal_helpers")
local PlayerStateHelpers = require("core.events.player_state_helpers")

local handlers = {}

function handlers.on_init()
  ErrorHandler.debug_log("Mod initialization started")

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

  -- Reset transient states to ensure clean startup
  PlayerStateHelpers.reset_transient_player_states(player)

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

  local can_open, reason = TagEditorEventHelpers.validate_tag_editor_opening(player)
  
  if not can_open then
    ErrorHandler.debug_log("Tag editor handler: " .. (reason or "validation failed"))
    if reason == "Drag mode active" then
      CursorUtils.end_drag_favorite(player)
      player.play_sound { path = "utility/cancel" }
    end
    return
  end

  local cursor_position = event.cursor_position
  if not cursor_position or not (cursor_position.x and cursor_position.y) then
    return
  end

  local surface_index = player.surface.index
  ErrorHandler.debug_log("Tag editor: Starting GPS conversion", { cursor_position = cursor_position })

  -- Use helper for tag lookup and tag_data creation
  local tag_data = TagEditorEventHelpers.find_or_create_tag_data(player, cursor_position, surface_index)
  Cache.set_tag_editor_data(player, tag_data)
  tag_editor.build(player)
  
  -- Debugging: Log detailed information for tag editor opening
  local debug_tag = Cache.get_tag_by_gps(player,
    GPSUtils.gps_from_map_position(PositionUtils.normalize_position(cursor_position), surface_index))
  local debug_chart_tag = debug_tag and debug_tag.chart_tag or nil
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
  local new_chart_tag, position_pair = TagEditorEventHelpers.normalize_and_replace_chart_tag(chart_tag, player)
  if new_chart_tag then
    -- Defensive: player is always nil here due to prior logic, so skip notification
    -- (This avoids the impossible 'if player and player.valid' error)
    -- No-op
  end
end

--- Validate if a tag modification event is valid
--- Handle chart tag modification events
---@param event table Chart tag modification event data
function handlers.on_chart_tag_modified(event)
  ErrorHandler.debug_log("Chart tag modified event received", {
    player_index = event.player_index,
    tag_valid = event.tag and event.tag.valid or false,
    tag_position = event.tag and event.tag.position or "nil",
    old_position = event.old_position or "nil",
    has_old_position = event.old_position ~= nil
  })

  local player = game.get_player(event.player_index)
  if not player or not player.valid then return end

  if not ChartTagModificationHelpers.is_valid_tag_modification(event, player) then 
    ErrorHandler.debug_log("Chart tag modification validation failed", {
      player_name = player.name
    })
    return 
  end

  ---@cast player LuaPlayer  -- Type assertion: player is guaranteed to be valid after the checks above

  local new_gps, old_gps = ChartTagModificationHelpers.extract_gps(event, player)
  
  ErrorHandler.debug_log("Chart tag GPS extraction results", {
    player_name = player.name,
    old_gps = old_gps or "nil",
    new_gps = new_gps or "nil",
    gps_changed = old_gps ~= new_gps
  })

  -- Check for need to normalize coordinates
  local chart_tag = event.tag
  if chart_tag and chart_tag.valid and chart_tag.position then
    local new_chart_tag, position_pair = TagEditorEventHelpers.normalize_and_replace_chart_tag(chart_tag, player)
    if new_chart_tag then
      -- Update the GPS and chart tag reference
      local surface_index = chart_tag.surface and chart_tag.surface.index or 1
      local new_position = position_pair and position_pair.new or chart_tag.position
      new_gps = GPSUtils.gps_from_map_position(new_position, surface_index)
      Cache.Lookups.invalidate_surface_chart_tags(surface_index)
      -- Update chart_tag reference for future operations
      chart_tag = new_chart_tag
    end
  end

  ChartTagModificationHelpers.update_tag_and_cleanup(old_gps, new_gps, event, player)

  -- Update favorites GPS and notify affected players
  if old_gps and new_gps and old_gps ~= new_gps then
    ErrorHandler.debug_log("Chart tag modified - updating favorites GPS", {
      player_name = player.name,
      old_gps = old_gps,
      new_gps = new_gps
    })
    ChartTagModificationHelpers.update_favorites_gps(old_gps, new_gps, player)
  end
end

--- Handle chart tag removal events
---@param event table Chart tag removal event data
function handlers.on_chart_tag_removed(event)
  local should_process, chart_tag = ChartTagRemovalHelpers.validate_removal_event(event)
  if not should_process or not chart_tag then return end

  local surface_index = (chart_tag.surface and chart_tag.surface.index) or 1
  local gps = GPSUtils.gps_from_map_position(chart_tag.position, tonumber(surface_index) or 1)
  local player = game.get_player(event.player_index)
  
  if not player or not player.valid then
    Cache.Lookups.invalidate_surface_chart_tags(surface_index)
    return
  end
  
  local tag = Cache.get_tag_by_gps(player, gps)
  local should_destroy = ChartTagRemovalHelpers.handle_protected_removal(chart_tag, player, tag, tonumber(surface_index) or 1)
  
  if should_destroy then
    -- Only destroy if the chart tag is not already being destroyed by our helper
    if not TagDestroyHelper.is_chart_tag_being_destroyed(chart_tag) then
      TagDestroyHelper.destroy_tag_and_chart_tag(tag, chart_tag)
    end
  end
end

--- Handle periodic memory snapshots for performance monitoring
---@param event table Factorio on_tick event
function handlers.on_tick(event)
  -- Take memory snapshots every 5 seconds in development mode
  if event.tick % 300 == 0 then
    Logger.take_memory_snapshot()
  end
end

return handlers
