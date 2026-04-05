local ErrorHandler = require("core.utils.error_handler")
local _serpent_ok, serpent = pcall(require, "serpent")
if not _serpent_ok then serpent = nil end
-- Global logger for all chart tag events
local function log_chart_tag_event(event, event_type)
  if not event then return end
  local tag = event.tag
  local tag_info = tag and tag.valid and (tag.text or tag.icon or tag.position or tag.surface) or "[invalid tag]"
  ErrorHandler.debug_log("[CHART_TAG_EVENT][" .. event_type .. "] tag_info=" .. serpent.line(tag_info))
end
if ErrorHandler and ErrorHandler.debug_log then
  ErrorHandler.debug_log("[TAG_MODIFIED][HANDLER_ENTER] Handler called", {
    event = event,
    player_index = event and event.player_index or "<nil>",
    tag = event and event.tag or "<nil>"
  })
end
-- icon typing moved into IconUtils
---@diagnostic disable: undefined-global

-- core/events/handlers.lua
-- TeleportFavorites Factorio Mod
-- Centralized event handler implementations for TeleportFavorites.
-- Handles Factorio events, multiplayer/surface-aware updates, helpers, error handling, validation, and API for all event types.

local AdminUtils = require("core.utils.admin_utils")
local BasicHelpers = require("core.utils.basic_helpers")
local ControlTagEditor = require("core.control.control_tag_editor")
local GameHelpers = require("core.utils.game_helpers")
local Cache = require("core.cache.cache")
local Constants = require("constants")
local PositionUtils = require("core.utils.position_utils")
local GPSUtils = require("core.utils.gps_utils")
local ErrorHandler = require("core.utils.error_handler")
local CursorUtils = require("core.utils.cursor_utils")
local tag_editor = require("gui.tag_editor.tag_editor")
local TagEditorEventHelpers = require("core.events.tag_editor_event_helpers")
local PlayerFavorites = require("core.favorite.player_favorites")
local GuiValidation = require("core.utils.gui_validation")
local fave_bar = require("gui.favorites_bar.fave_bar")
local Enum = require("prototypes.enums.enum")
local tag_destroy_helper = require("core.tag.tag_destroy_helper")
local teleport_history_modal = require("gui.teleport_history_modal.teleport_history_modal")
local ChartTagHelpers = require("core.events.chart_tag_helpers")
local gui_observer = require("core.events.gui_observer")


-- Helper functions for surface refresh and captions

--- Close all mod screen-level GUIs for a player (tag editor, modals, history)
--- Called during save/load and player (re)join to prevent stale/orphaned GUI frames
---@param player LuaPlayer
local function close_all_mod_screens(player)
  if not player or not player.valid then return end
  ControlTagEditor.close_tag_editor(player)
  GuiValidation.safe_destroy_frame(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR_DELETE_CONFIRM)
  GuiValidation.safe_destroy_frame(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TELEPORT_HISTORY_MODAL)
  GuiValidation.safe_destroy_frame(player.gui.screen, Enum.UIEnums.GUI.TeleportHistory.CONFIRM_DIALOG_FRAME)
end

---@param player LuaPlayer
---@return boolean
local function has_any_mod_screen_gui(player)
  if not player or not player.valid then return false end
  local screen = player.gui and player.gui.screen
  if not screen or not screen.valid then return false end

  return (screen[Enum.GuiEnum.GUI_FRAME.TAG_EDITOR] and screen[Enum.GuiEnum.GUI_FRAME.TAG_EDITOR].valid)
      or (screen[Enum.GuiEnum.GUI_FRAME.TAG_EDITOR_DELETE_CONFIRM] and screen[Enum.GuiEnum.GUI_FRAME.TAG_EDITOR_DELETE_CONFIRM].valid)
      or (screen[Enum.GuiEnum.GUI_FRAME.TELEPORT_HISTORY_MODAL] and screen[Enum.GuiEnum.GUI_FRAME.TELEPORT_HISTORY_MODAL].valid)
      or (screen[Enum.UIEnums.GUI.TeleportHistory.CONFIRM_DIALOG_FRAME] and screen[Enum.UIEnums.GUI.TeleportHistory.CONFIRM_DIALOG_FRAME].valid)
end

---@param surface_index number The surface index to refresh chart tags for
--- Restore a chart tag that was removed and refresh caches/UI
---@param player LuaPlayer The player
---@param chart_tag LuaCustomChartTag The removed chart tag (still valid during event)
---@param tag table? The mod's Tag object
local function restore_chart_tag_and_refresh(player, chart_tag, tag)
  if chart_tag.position and chart_tag.surface then
    local new_chart_tag = player.force.add_chart_tag(
      player.surface,
      {
        position = chart_tag.position,
        text = chart_tag.text or "",
        icon = chart_tag.icon,
        last_user = chart_tag.last_user
      }
    )
    if tag then
      tag.chart_tag = new_chart_tag
    end
    -- UPS OPTIMIZATION: Targeted upsert for restored tag (same GPS, new chart_tag object)
    if new_chart_tag and new_chart_tag.valid then
      local surface_index = player.surface and player.surface.valid and player.surface.index or 1
      local gps = GPSUtils.gps_from_map_position(new_chart_tag.position, tonumber(surface_index) or 1)
      if gps then
        Cache.Lookups.upsert_chart_tag_in_cache(gps, new_chart_tag)
      end
    end
  end
  fave_bar.update_all_slots_in_place(player)
end


---@param ... any Additional arguments to pass to handler
---@return any Result from handler function, or nil if player invalid
-- Shared player validation using centralized helpers
local function with_valid_player(player_index, handler_fn, ...)
  if not player_index then return nil end
  local player = game.players[player_index]
  if not BasicHelpers.is_valid_player(player) then return nil end
  return handler_fn(player, ...)
end


-- Initialize error handler log level from configuration (do not force debug)
local configured_log_level = (Constants and Constants.settings and Constants.settings.DEFAULT_LOG_LEVEL) or "production"
ErrorHandler.initialize(configured_log_level)

local handlers = {}

---@param phase string
---@param player LuaPlayer|nil
---@param context table|nil
local function log_deferred_init_phase(phase, player, context)
  if not ErrorHandler.should_log_debug() then return end
  local log_context = context or {}
  log_context.tick = game and game.tick or 0
  if player and player.valid then
    log_context.player_index = player.index
    log_context.player_name = player.name
  end
  ErrorHandler.debug_log("[DEFERRED_INIT] " .. phase, log_context)
end

local function register_gui_observers(player)
  if not player or not player.valid then
    ErrorHandler.warn_log("Attempted to register observers for invalid player")
    return
  end

  -- Initialize event bus
  gui_observer.GuiEventBus.ensure_initialized()

  -- Register player observers
  local register_ok, err = pcall(function()
    gui_observer.GuiEventBus.register_player_observers(player)
  end)

  if not register_ok then
    ErrorHandler.warn_log("Failed to register GUI observers", {
      player = player.name,
      error = err
    })
  end
end

function handlers.on_player_changed_surface(event)
  with_valid_player(event.player_index, function(player)
    if player.surface and player.surface.valid then
      -- Close tag editor if open (tag belongs to old surface)
      ControlTagEditor.close_tag_editor(player)

      Cache.ensure_surface_cache(player.surface.index)

      -- Force rebuild to show the new surface's favorites (skips tick debounce)
      fave_bar.build(player, true)
      -- Ensure visibility is updated for the new surface
      fave_bar.update_fave_bar_visibility(player)

      -- Refresh teleport history modal if open (show new surface's history)
      if teleport_history_modal.is_open(player) then
        teleport_history_modal.update_history_list(player)
      end
    end
  end)
end

function handlers.on_init()
  if ErrorHandler and ErrorHandler.debug_log then
    ErrorHandler.debug_log("handlers.on_init() called")
  end
  -- Initialize the GUI event bus first
  gui_observer.GuiEventBus.ensure_initialized()
  ErrorHandler.debug_log("GUI Event Bus initialized during startup")

  -- Initialize cache system
  if Constants.settings.DEFAULT_LOG_LEVEL == "debug" then
    ErrorHandler.debug_log("[Cache] Cache.init() called during on_init")
  end
  Cache.init()

  -- Touch connected player data only; observer registration and GUI work are deferred
  -- to the startup queue on on_nth_tick(2) to avoid init-time spikes.
  for _, player in pairs(game.connected_players) do
    if player and player.valid and player.connected then
      Cache.get_player_data(player)
    end
  end

  if Constants.settings.DEFAULT_LOG_LEVEL == "debug" then
    ErrorHandler.debug_log("[INIT] Startup initialization complete - GUI build deferred to player join")
  end
end

-- Session-level flag (NOT in storage, safe for on_load)
-- This gets reset every time the mod is loaded
local observers_registered_this_session = false

function handlers.on_load()
  -- Re-initialize GUI event bus on game load
  gui_observer.GuiEventBus.ensure_initialized()
  ErrorHandler.debug_log("GUI Event Bus re-initialized on game load")

  -- CRITICAL: Reset the session flag so observers get registered on tick 1
  -- Using global variable instead of storage (can't modify storage in on_load)
  observers_registered_this_session = false
  ErrorHandler.debug_log("[ON_LOAD] Reset observer registration flag", {
    flag_value = observers_registered_this_session
  })
end

-- Queue for deferred player initialization
-- Each entry: { player_index = N, is_rejoin = bool }
-- Declared before on_configuration_changed so it can enqueue players during config changes
local _deferred_init_queue = {}
local _deferred_init_pending = {}

--- Enqueue a player for deferred initialization
--- on_nth_tick(2) is permanently registered at load time; it processes whatever is in the queue
---@param player_index uint
---@param is_rejoin boolean
---@param priority_front boolean|nil
---@param phase string|nil
local function enqueue_deferred_init(player_index, is_rejoin, priority_front, phase)
  if not player_index then return end
  if _deferred_init_pending[player_index] then return end
  _deferred_init_pending[player_index] = true
  local entry = { player_index = player_index, is_rejoin = is_rejoin, phase = phase or "prepare_a" }
  if priority_front then
    table.insert(_deferred_init_queue, 1, entry)
  else
    table.insert(_deferred_init_queue, entry)
  end
end

--- Handle mod configuration changes (mod update, added/removed mods)
--- Destroys existing fave bars and defers rebuild to reduce startup UPS spikes.
--- The rebuild happens via the deferred init queue (on_nth_tick(2)) instead of synchronously.
function handlers.on_configuration_changed(data)
  ErrorHandler.debug_log("[CONFIG_CHANGED] Configuration changed, deferring fave bar rebuilds")
  for _, player in pairs(game.players) do
    if player.valid then
      -- Ensure player data is initialized (get_player_data calls init internally)
      Cache.get_player_data(player)
      -- Destroy existing fave bar immediately (prevents stale GUI clicks)
      local main_flow = player.gui.top[Enum.UIEnums.GUI.Shared.MAIN_GUI_FLOW]
      if main_flow and main_flow.valid then
        GuiValidation.safe_destroy_frame(main_flow, Enum.GuiEnum.GUI_FRAME.FAVE_BAR)
      end
      -- Defer the rebuild to spread work across ticks (deduplicates with on_player_joined_game)
      enqueue_deferred_init(player.index, true)
    end
  end
end

function handlers.get_observers_registered_flag()
  return observers_registered_this_session
end

function handlers.set_observers_registered_flag(value)
  observers_registered_this_session = value
end

--- Enqueue all current players for deferred initialization once per session.
--- Needed on save-load sessions where on_player_joined_game may not fire for already connected players.
function handlers.enqueue_all_players_for_deferred_init()
  for _, player in pairs(game.connected_players) do
    if player and player.valid and player.connected then
      enqueue_deferred_init(player.index, true)
    end
  end
end

--- Process all queued player initializations
--- on_nth_tick(2) stays permanently registered for multiplayer safety; it no-ops when queue is empty
--- Deduplicates entries by player_index so each player is only initialized once per batch
---@return boolean|string did_work_or_phase
function handlers.process_deferred_init_queue()
  if #_deferred_init_queue == 0 then return false end

  -- UPS OPTIMIZATION: Process one player per tick to spread GUI build work across multiple ticks.
  -- Building all players' favorites bars on tick 60 caused 17ms+ spikes with 100+ YARM tags.
  -- By processing one player per tick, work spreads naturally across ~60ms window.
  
  local entry = table.remove(_deferred_init_queue, 1)  -- FIFO: process first player
  if not entry then return false end
  local phase = entry.phase or "prepare"

  local deferred_player = game.players[entry.player_index]
  if deferred_player and deferred_player.valid and deferred_player.connected then
    if phase == "prepare_a" then
      log_deferred_init_phase("prepare_a.begin", deferred_player)
      Cache.reset_transient_player_states(deferred_player)

      -- Close any stale mod GUIs from previous session (tag editor, modals, etc.)
      local should_close_screens = has_any_mod_screen_gui(deferred_player)
      if should_close_screens then
        close_all_mod_screens(deferred_player)
      end

      table.insert(_deferred_init_queue, 1, {
        player_index = entry.player_index,
        is_rejoin = entry.is_rejoin,
        phase = "build"
      })
      log_deferred_init_phase("prepare_a.end", deferred_player)
      return "prepare"
    end

    if phase == "build" then
      log_deferred_init_phase("build.begin", deferred_player)
      -- Build phase: lightweight authoritative queue handoff.
      Cache.invalidate_rehydrated_favorites(deferred_player)
      fave_bar.enqueue_startup_build(deferred_player, true)

      table.insert(_deferred_init_queue, 1, {
        player_index = entry.player_index,
        is_rejoin = entry.is_rejoin,
        phase = "observers"
      })
      log_deferred_init_phase("build.end", deferred_player)
      return "build"
    end

    if phase == "observers" then
      log_deferred_init_phase("observers.begin", deferred_player)
      local has_notification_observer = gui_observer.GuiEventBus.has_player_observer(
        deferred_player.index,
        "invalid_chart_tag",
        "notification"
      )

      if entry.is_rejoin and not has_notification_observer then
        gui_observer.GuiEventBus.cleanup_player_observers(deferred_player)
      end

      if not has_notification_observer then
        register_gui_observers(deferred_player)
      end

      _deferred_init_pending[entry.player_index] = nil
      log_deferred_init_phase("observers.end", deferred_player)
      return "observers"
    end
  end

  _deferred_init_pending[entry.player_index] = nil
  return false
end

function handlers.on_player_created(event)
  with_valid_player(event.player_index, function(player)
    enqueue_deferred_init(player.index, false, true)
  end)
end

function handlers.on_player_joined_game(event)
  with_valid_player(event.player_index, function(player)
    ErrorHandler.debug_log("Deferring initialization for rejoining player", {
      player = player.name,
      player_index = player.index
    })
    -- Priority enqueue so the active joining player's bar appears ASAP.
    enqueue_deferred_init(player.index, true, true)
  end)
end

function handlers.on_open_tag_editor_custom_input(event)
  with_valid_player(event.player_index, function(player)
    local can_open, reason = TagEditorEventHelpers.validate_tag_editor_opening(player)
    if not can_open then
      if reason == "Drag mode active" then
        CursorUtils.end_drag_favorite(player)
        if player and player.play_sound then
          player.play_sound { path = "utility/cannot_build" }
        end
      end
      return
    end


    local tag_data = Cache.get_player_data(player).tag_editor_data or Cache.create_tag_editor_data()
    local cursor_position = event.cursor_position
    -- Force invalidate and warm-up of chart tag cache for this surface before searching
    if Cache.Lookups and Cache.Lookups.invalidate_surface_chart_tags and Cache.Lookups.warm_surface_gps_map then
      Cache.Lookups.invalidate_surface_chart_tags(player.surface.index)
      if ErrorHandler and ErrorHandler.debug_log then
        ErrorHandler.debug_log("[TAG_EDITOR][OPEN] Invalidated chart tag cache for surface", { surface_index = player.surface.index })
      end
      Cache.Lookups.warm_surface_gps_map(player.surface.index)
      if ErrorHandler and ErrorHandler.debug_log then
        ErrorHandler.debug_log("[TAG_EDITOR][OPEN] Warming chart tag cache for surface", { surface_index = player.surface.index })
      end
    end
    -- Use updated radius for tag search: 11 tiles
    local chart_tag = cursor_position and cursor_position.x and cursor_position.y and
      TagEditorEventHelpers.find_nearby_chart_tag(cursor_position, player.surface.index, 11)
    -- Debug: Dump cache contents after scan
    if Cache.Lookups and Cache.Lookups.get_chart_tag_cache and ErrorHandler and ErrorHandler.debug_log then
      local tags = Cache.Lookups.get_chart_tag_cache(player.surface.index)
      local tag_dump = {}
      for i, tag in ipairs(tags) do
        table.insert(tag_dump, {
          index = i,
          gps = tag.position and GPSUtils.gps_from_map_position(tag.position, player.surface.index) or "<nil>",
          force = tag.force and tag.force.name or "<nil>",
          surface = tag.surface and tag.surface.name or "<nil>",
          valid = tag.valid,
          text = tag.text or ""
        })
      end
      ErrorHandler.debug_log("[TAG_EDITOR][OPEN] Cache contents after scan", {
        surface_index = player.surface.index,
        tag_count = #tags,
        tags = tag_dump
      })
    end
    if ErrorHandler and ErrorHandler.debug_log then
      ErrorHandler.debug_log("[TAG_EDITOR][OPEN] find_nearby_chart_tag result", {
        found = chart_tag ~= nil,
        chart_tag_valid = chart_tag and chart_tag.valid or false,
        chart_tag_pos = chart_tag and chart_tag.position or nil,
        cursor_position = cursor_position,
        surface_index = player.surface.index
      })
    end


    if chart_tag and chart_tag.valid then
      local icon = IconUtils.get_canonical_icon(chart_tag and chart_tag.icon or nil)
      local tag = Cache.get_tag_by_gps(player, gps)
      tag_data.chart_tag = chart_tag
      if tag then
        tag_data.tag = tag
      else
        tag_data.tag = {
          chart_tag = chart_tag,
          gps = gps,
          text = chart_tag.text,
          owner_name = nil,
          faved_by_players = {},
        }
      end
      tag_data.gps = gps
      tag_data.is_favorite = favorite_entry ~= nil
      tag_data.icon = icon
      local chart_text = chart_tag.text
      tag_data.text = type(chart_text) == "string" and chart_text or ""
    else
      -- No matching tag found: use clicked position for GPS
      if cursor_position and cursor_position.x and cursor_position.y and player and player.surface and player.surface.index then
        local gps = GPSUtils.gps_from_map_position(cursor_position, player.surface.index)
        tag_data.gps = gps
        tag_data.chart_tag = nil
        tag_data.tag = {
          chart_tag = nil,
          gps = gps,
          text = "",
          owner_name = player.name,
          faved_by_players = {},
        }
        tag_data.is_favorite = false
        tag_data.icon = nil
        tag_data.text = ""
        if ErrorHandler and ErrorHandler.debug_log then
          ErrorHandler.debug_log("[TAG_EDITOR][OPEN] No tag found, using clicked position for GPS", { gps = gps, cursor_position = cursor_position, surface_index = player.surface.index })
        end
      elseif tag_data.tag and tag_data.tag.gps and tag_data.tag.gps ~= "" then
        tag_data.gps = tag_data.tag.gps
      end
    end

    -- (No fallback to tag.icon: forbidden)
    Cache.set_tag_editor_data(player, tag_data)
    tag_editor.build(player)
  end)
end

function handlers.on_chart_tag_added(event)
      log_chart_tag_event(event, "ADDED")
    if ErrorHandler and ErrorHandler.debug_log then
      ErrorHandler.debug_log("[TAG_ADDED][HANDLER_ENTER] Handler called", {
        event = event,
        player_index = event and event.player_index or "<nil>",
        tag = event and event.tag or "<nil>"
      })
    end
  -- Get the player object from the event.player_index (can be nil if added by script)
  if not event.player_index then
    -- Script-generated chart tag events are common at startup (other mods); skip noisy logging.
    return
  end

  local player = game.players[event.player_index]
  if not player or not player.valid then return end
  local surface_index = player and player.surface and player.surface.index or nil

  -- Ensure the position of the added tag is normalized
  local chart_tag = event.tag
  if chart_tag and chart_tag.valid and chart_tag.position then
    if PositionUtils.needs_normalization(chart_tag.position) then
      ErrorHandler.debug_log("Chart tag added with fractional coordinates, normalizing", {
        player_name = player.name,
        position = chart_tag.position
      })
      -- UPS OPTIMIZATION: normalize_and_replace_chart_tag handles targeted cache evict+upsert internally.
      -- Return early — the old chart_tag is destroyed after this call and further processing is invalid.
      TagEditorEventHelpers.normalize_and_replace_chart_tag(chart_tag, player)
      return
    end
  end

  -- UPS OPTIMIZATION: Targeted O(1) cache upsert instead of no-op ensure_surface_cache.
  -- ensure_surface_cache was a no-op on warm cache, leaving the new tag out of the GPS mapping.
  local surface_index = player.surface and player.surface.valid and player.surface.index or 1
  if chart_tag and chart_tag.valid then
    local gps = GPSUtils.gps_from_map_position(chart_tag.position, tonumber(surface_index) or 1)
    if gps then
      Cache.Lookups.upsert_chart_tag_in_cache(gps, chart_tag)
      -- Debug: log tag properties immediately after creation
      if ErrorHandler and ErrorHandler.debug_log then
        ErrorHandler.debug_log("[TAG_ADD][IMMEDIATE] Created chart tag", {
          gps = gps,
          position = chart_tag.position,
          text = chart_tag.text or "",
          icon = chart_tag.icon,
          valid = chart_tag.valid,
          force = chart_tag.force and chart_tag.force.name or "<nil>",
          surface = chart_tag.surface and chart_tag.surface.name or "<nil>"
        })
      end
      -- Invalidate array cache immediately (Factorio API: cannot raise on_tick event via script)
      if Cache and Cache.Lookups and Cache.Lookups.clear_surface_cache_chart_tags then
        Cache.Lookups.clear_surface_cache_chart_tags(surface_index)
        if ErrorHandler and ErrorHandler.debug_log then
          ErrorHandler.debug_log("[TAG_ADD][IMMEDIATE] Cleared surface cache after tag add", {surface_index=surface_index})
        end
      end

      -- Check for pending tag move info and hydrate new tag if present
      local integer_surface_index = surface_index --[[@as integer]]
      local surface_tags = Cache.get_surface_tags(integer_surface_index)
      local tag = surface_tags and surface_tags[gps] or nil
      local pending_info = Cache.pop_pending_tag_move(player, gps)
      if tag and type(tag) == "table" and pending_info then
        tag.owner_name = pending_info.owner_name or player.name
        tag.faved_by_players = pending_info.faved_by_players or {}
        tag.text = pending_info.text or tag.text
        tag.icon = pending_info.icon or tag.icon
        if ErrorHandler and ErrorHandler.debug_log then
          ErrorHandler.debug_log("[TAG_ADD][HYDRATE] Hydrated new tag with pending move info", {
            gps = gps,
            owner_name = tag.owner_name,
            faved_by_players = tag.faved_by_players,
            text = tag.text,
            icon = tag.icon
          })
        end
      elseif tag and type(tag) == "table" then
        tag.owner_name = player.name
        ErrorHandler.debug_log("Stored tag owner on creation", {
          gps = gps,
          owner_name = player.name
        })
      end
    end
  end
end

function handlers.on_chart_tag_modified(event)
      log_chart_tag_event(event, "MODIFIED")
    if ErrorHandler and ErrorHandler.debug_log then
      ErrorHandler.debug_log("[TAG_MODIFIED][EVENT_FIRED] on_chart_tag_modified called", {
        event = event,
        player_index = event and event.player_index or nil,
        old_position = event and event.old_position or nil
      })
    end
  if not event or not event.old_position then return end

  -- Check for valid player_index (can be nil if modified by script)
  if not event.player_index then return end

  local player = game.players[event.player_index]
  if not player or not player.valid then return end

  -- UPS OPTIMIZATION: Early-exit for chart tags not tracked by this mod.
  -- Other mods (e.g. YARM) modify their own chart tags periodically, firing on_chart_tag_modified.
  -- If the tag at the old position isn't in our storage, skip all processing.
  -- Use a storage-only lookup here so third-party tag traffic doesn't trigger
  -- invalid_chart_tag notifications or chart-tag runtime lookup work.
  local new_gps, old_gps = ChartTagHelpers.extract_gps(event, player)

  -- Deterministic lookup: try multiple plausible surface contexts for old GPS
  local old_tag = nil
  local tried_surface = {}
  local function try_surface_lookup(sidx)
    if not sidx or tried_surface[sidx] then return nil end
    tried_surface[sidx] = true
    local surface_tags = Cache.get_surface_tags(sidx)
    if not surface_tags then return nil end
    local candidate_old_gps = old_gps or (event.old_position and GPSUtils.gps_from_map_position(event.old_position, sidx))
    if candidate_old_gps and surface_tags[candidate_old_gps] then
      old_gps = candidate_old_gps
      return surface_tags[candidate_old_gps]
    end
    return nil
  end

  -- Try event.tag.surface (authoritative if present), then player.surface, then fallback to stored surface_index
  local tag_surface_index = event.tag and event.tag.valid and event.tag.surface and event.tag.surface.valid and event.tag.surface.index or nil
  local player_surface_index = player and player.valid and player.surface and player.surface.valid and player.surface.index or nil
  old_tag = try_surface_lookup(tag_surface_index) or try_surface_lookup(player_surface_index)

  -- If the tag is missing from storage, log a warning but proceed to update the favorite GPS.
  if not old_tag then
    if ErrorHandler and ErrorHandler.warn_log then
      ErrorHandler.warn_log("[FAV_UPDATE][WARNING] Tag not found in storage during tag move. Proceeding to update favorite GPS.", {
        player = player and player.name or "<nil>",
        old_gps = old_gps,
        new_gps = new_gps,
        event = event
      })
    end
  else
    -- Store old tag info in pending moves for later hydration
    Cache.set_pending_tag_move(player, old_gps, {
      owner_name = old_tag.owner_name,
      faved_by_players = old_tag.faved_by_players,
      text = old_tag.text,
      icon = old_tag.icon
    })
    if ErrorHandler and ErrorHandler.debug_log then
      ErrorHandler.debug_log("[TAG_MOVE][PENDING] Stored pending tag move info", {
        player = player.name,
        old_gps = old_gps,
        info = {
          owner_name = old_tag.owner_name,
          faved_by_players = old_tag.faved_by_players,
          text = old_tag.text,
          icon = old_tag.icon
        }
      })
    end
  end

  -- OWNERSHIP PRESERVATION: Get the original owner from our Tag storage
  -- event.old_player_index is unreliable (often nil), so we track ownership in Tag.owner_name
  local original_owner = nil
  local original_owner_name = nil

  -- Debug: log tag modification event
  if ErrorHandler and ErrorHandler.debug_log then
    ErrorHandler.debug_log("[TAG_MODIFIED][IMMEDIATE] Tag modified event", {
      old_gps = old_gps,
      new_gps = new_gps,
      surface_index = surface_index
    })
  end
  -- Invalidate array cache immediately (Factorio API: cannot raise on_tick event via script)
  if surface_index then
    if Cache and Cache.Lookups and Cache.Lookups.clear_surface_cache_chart_tags then
      Cache.Lookups.clear_surface_cache_chart_tags(surface_index)
      if ErrorHandler and ErrorHandler.debug_log then
        ErrorHandler.debug_log("[TAG_MODIFIED][IMMEDIATE] Cleared surface cache after tag move", {surface_index=surface_index})
      end
    end
  end

  if old_tag and type(old_tag) == "table" and old_tag.owner_name then
    original_owner_name = old_tag.owner_name
    -- Find the player object by name
    for _, p in pairs(game.players) do
      if p.name == original_owner_name then
        original_owner = p
        break
      end
    end
  end

  -- Fallback to event.old_player_index if available
  if not original_owner_name and event.old_player_index then
    original_owner = game.players[event.old_player_index]
    if original_owner and original_owner.valid then
      original_owner_name = original_owner.name
    end
  end

  if not ChartTagHelpers.is_valid_tag_modification(event, player) then
    ErrorHandler.debug_log("Chart tag modification validation failed", {
      player_name = player.name
    })
    return
  end

  -- CHARTED TERRITORY VALIDATION: Prevent moving tags into uncharted areas
  local chart_tag = event.tag
  if chart_tag and chart_tag.valid and chart_tag.position then
    local surface = chart_tag.surface or player.surface
    local force = chart_tag.force or player.force

    -- Check if the new position is charted
    if surface and surface.valid and force and force.valid then
      -- Convert world position to chunk position for is_chunk_charted check
      local chunk_x = math.floor(chart_tag.position.x / 32)
      local chunk_y = math.floor(chart_tag.position.y / 32)
      local is_charted = force.is_chunk_charted(surface, { chunk_x, chunk_y })

      if not is_charted then
        -- Position is not charted - revert the tag to old position and play error sound
        chart_tag.position = event.old_position
        player.play_sound({ path = "utility/cannot_build" })

        ErrorHandler.debug_log("Prevented tag move to uncharted territory", {
          player_name = player.name,
          attempted_position = chart_tag.position,
          attempted_chunk = { chunk_x, chunk_y },
          old_position = event.old_position,
          surface_name = surface.name
        })

        return
      end
    end
  end

  local new_gps, old_gps = ChartTagHelpers.extract_gps(event, player)

  -- Check if this tag is currently open in the tag editor and update it
  local tag_editor_data = Cache.get_tag_editor_data(player)
  if tag_editor_data and tag_editor_data.gps == old_gps then
    -- Update the GPS in tag editor data
    tag_editor_data.gps = new_gps
    if tag_editor_data.tag then
      tag_editor_data.tag.gps = new_gps
    end
    Cache.set_tag_editor_data(player, tag_editor_data)
    -- Update the teleport button caption to show new coordinates
    local tag_editor_frame = GuiValidation.find_child_by_name(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR)
    if tag_editor_frame and tag_editor_frame.valid then
      local teleport_btn = GuiValidation.find_child_by_name(tag_editor_frame, "tag_editor_teleport_button")
      if teleport_btn and teleport_btn.valid then
        local gps_string = new_gps --[[@as string]]
        local coords = GPSUtils.coords_string_from_gps(gps_string) or ""
        -- Set caption using make_teleport_caption helper
        -- Set caption directly - Factorio API handles localization internally
        ---@diagnostic disable-next-line: assign-type-mismatch
        teleport_btn.caption = { "tf-gui.teleport_to", coords }
      end
    end
  end
  local chart_tag = event.tag
  if chart_tag and chart_tag.valid and chart_tag.position then
    local position_changed = old_gps and new_gps and old_gps ~= new_gps

    if PositionUtils.needs_normalization(chart_tag.position) then
      ErrorHandler.debug_log("Chart tag has fractional coordinates, normalizing", {
        player_name = player.name,
        position = chart_tag.position,
        old_gps = old_gps,
        new_gps = new_gps
      })

      local new_chart_tag, position_pair = TagEditorEventHelpers.normalize_and_replace_chart_tag(chart_tag, player)
      if new_chart_tag then
        -- After normalization, recalculate GPS coordinates for the new chart tag
        local surface_index = GPSUtils.get_context_surface_index(new_chart_tag, player)
        local normalized_gps = GPSUtils.gps_from_map_position(new_chart_tag.position, tonumber(surface_index) or 1)
        -- Update using the normalized GPS as the final new GPS
        if old_gps and normalized_gps and old_gps ~= normalized_gps then
          -- Create a modified event with the new chart tag for cleanup
          local normalized_event = {
            tag = new_chart_tag,
            old_position = event.old_position,
            player_index = event.player_index
          }
          ChartTagHelpers.update_tag_and_cleanup(old_gps, normalized_gps, normalized_event, player, original_owner_name)
          ChartTagHelpers.update_favorites_gps(old_gps, normalized_gps, player)
          if ErrorHandler and ErrorHandler.debug_log then
            ErrorHandler.debug_log("[TAG_MODIFIED][FAV_UPDATE] Called update_favorites_gps (normalized)", {
              player = player and player.name or "<nil>",
              old_gps = old_gps,
              new_gps = normalized_gps
            })
          end
        end
      end
      if old_gps and new_gps and old_gps ~= new_gps then
        -- Update tag data and cache using the original chart tag
        ChartTagHelpers.update_tag_and_cleanup(old_gps, new_gps, event, player, original_owner_name)
        ChartTagHelpers.update_favorites_gps(old_gps, new_gps, player)
        if ErrorHandler and ErrorHandler.debug_log then
          ErrorHandler.debug_log("[TAG_MODIFIED][FAV_UPDATE] Called update_favorites_gps", {
            player = player and player.name or "<nil>",
            old_gps = old_gps,
            new_gps = new_gps
          })
        end
      end
    elseif position_changed then
      -- If position changed but no normalization needed, still update tag and favorites
      if ErrorHandler and ErrorHandler.debug_log then
        ErrorHandler.debug_log("[TAG_MOVE] About to update favorites GPS", {
          old_gps = old_gps,
          new_gps = new_gps,
          player = player and player.name or "<nil>"
        })
      end
      ChartTagHelpers.update_tag_and_cleanup(old_gps, new_gps, event, player, original_owner_name)
      ChartTagHelpers.update_favorites_gps(old_gps, new_gps, player)
    else
      -- METADATA-ONLY CHANGE: Position unchanged, but text/icon may have changed
      -- Update tag metadata and refresh favorites bar for all affected players
      if new_gps then
        ChartTagHelpers.update_tag_metadata(new_gps, chart_tag, player)
      end
    end

    -- Ownership is preserved via Tag.owner_name field (no need to restore chart_tag.last_user)
  end
end

function handlers.on_chart_tag_removed(event)
      log_chart_tag_event(event, "REMOVED")
    if ErrorHandler and ErrorHandler.debug_log then
      ErrorHandler.debug_log("[TAG_REMOVED][HANDLER_ENTER] Handler called", {
        event = event,
        player_index = event and event.player_index or "<nil>",
        tag = event and event.tag or "<nil>"
      })
    end
  with_valid_player(event.player_index, function(player)
    local chart_tag = event.tag
    if not chart_tag or not chart_tag.valid then return end

    -- Get GPS and Tag object to check ownership via Tag.owner_name
    local gps = GPSUtils.gps_from_map_position(chart_tag.position,
      GPSUtils.get_context_surface_index(chart_tag, player))
    local surface_index = player.surface and player.surface.valid and player.surface.index or nil
    local surface_tags = surface_index and Cache.get_surface_tags(surface_index) or nil
    local tag = gps and surface_tags and surface_tags[gps] or nil

    -- UPS OPTIMIZATION: Early-exit for chart tags not tracked by this mod.
    -- Other mods (e.g. YARM) may remove their own chart tags; skip processing for those.
    if not tag then return end

    -- Only allow removal if player is admin or owner (using Tag.owner_name)
    local is_admin = player.admin
    local is_owner = tag and (not tag.owner_name or tag.owner_name == "" or tag.owner_name == player.name)

    -- Overrides to vanilla behavior, giving us a way to "put the tag back" if a vanilla deletion breaks the mod's rules
    if not is_admin and not is_owner then
      restore_chart_tag_and_refresh(player, chart_tag, tag)
      return
    end


    local player_favorites = Cache.get_player_favorites(player, chart_tag.surface.index) or {}
    local is_locked = false

    for _, v in ipairs(player_favorites) do
      if v.gps and v.gps == gps and v.locked == true then
        -- Reject the change due to locked status
        is_locked = true
        break
      end
    end

    if is_locked == true then
      -- Notify player that favorite is locked
      GameHelpers.player_print(player, { "tf-gui.favorite_locked_cant_delete" })
      restore_chart_tag_and_refresh(player, chart_tag, tag)
      return
    end

    -- Remove/update associated tags, favorites, etc.
    tag_destroy_helper.destroy_tag_and_chart_tag(tag, chart_tag)

    -- UPS OPTIMIZATION: Targeted cache eviction instead of no-op refresh_surface_chart_tags
    if gps then
      Cache.Lookups.evict_chart_tag_from_cache(gps)
    end
    fave_bar.update_all_slots_in_place(player)
  end)
end

return handlers
