---@diagnostic disable: undefined-global

-- core/events/handlers.lua
-- TeleportFavorites Factorio Mod
-- Centralized event handler implementations for TeleportFavorites.
-- Chart-tag handlers live in handlers_chart_tag.lua (extend pattern).

local Deps = require("core.deps_barrel")
local ErrorHandler, Cache, Constants, Enum, BasicHelpers =
  Deps.ErrorHandler, Deps.Cache, Deps.Constants, Deps.Enum, Deps.BasicHelpers
local ControlTagEditor = require("core.control.control_tag_editor")
local GuiValidation = require("core.utils.gui_validation")
local fave_bar = require("gui.favorites_bar.fave_bar")
local teleport_history_modal = require("gui.teleport_history_modal.teleport_history_modal")
local gui_observer = require("core.events.gui_observer")
local PlayerFavorites = require("core.favorite.player_favorites")
local with_valid_player = BasicHelpers.with_valid_player

--- Close all mod screen-level GUIs for a player (tag editor, modals, history)
---@param player LuaPlayer
local function close_all_mod_screens(player)
  ControlTagEditor.close_tag_editor(player)
  GuiValidation.safe_destroy_frame(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR_DELETE_CONFIRM)
  GuiValidation.safe_destroy_frame(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TELEPORT_HISTORY_MODAL)
  GuiValidation.safe_destroy_frame(player.gui.screen, Enum.UIEnums.GUI.TeleportHistory.CONFIRM_DIALOG_FRAME)
end

local handlers = {}

local function register_gui_observers(player)
  ErrorHandler.debug_log("Starting GUI observer registration", {
    player = player.name,
    player_index = player.index
  })

  local register_ok, err = pcall(function()
    gui_observer.GuiEventBus.register_player_observers(player)
  end)

  if register_ok then
    ErrorHandler.debug_log("Successfully registered GUI observers", {
      player = player.name,
      player_index = player.index
    })
  else
    ErrorHandler.warn_log("Failed to register GUI observers", {
      player = player.name,
      error = err
    })
  end
end

function handlers.on_player_changed_surface(event)
  with_valid_player(event.player_index, function(player)
    PlayerFavorites.invalidate_instance_cache_for_player(event.player_index)
    fave_bar.clear_session_gui_refs(event.player_index)
    if player.surface and player.surface.valid then
      ControlTagEditor.close_tag_editor(player)
      Cache.ensure_surface_cache(player.surface.index)
      fave_bar.build(player, true)
      fave_bar.update_fave_bar_visibility(player)
      if teleport_history_modal.is_open(player) then
        teleport_history_modal.update_history_list(player)
      end
    end
  end)
end

function handlers.on_init()
  ErrorHandler.debug_log("GUI Event Bus ready during startup")

  if Constants.settings.DEFAULT_LOG_LEVEL == "debug" then
    ErrorHandler.debug_log("[Cache] Cache.init() called during on_init")
  end
  Cache.init()

  BasicHelpers.for_each_player_by_index_asc(function(player)
    register_gui_observers(player)
  end)

  if Constants.settings.DEFAULT_LOG_LEVEL == "debug" then
    ErrorHandler.debug_log("[INIT] Startup initialization complete - GUI build deferred to player join")
  end
end

-- Session-level flag (NOT in storage, safe for on_load)
local observers_registered_this_session = false

function handlers.on_load()
  ErrorHandler.debug_log("GUI Event Bus ready on game load")
  observers_registered_this_session = false
  ErrorHandler.debug_log("[ON_LOAD] Reset observer registration flag", {
    flag_value = observers_registered_this_session
  })
end

--- Handle mod configuration changes (mod update, added/removed mods)
function handlers.on_configuration_changed(data)
  ErrorHandler.debug_log("[CONFIG_CHANGED] Configuration changed, clearing stale fave bars")
  storage._tf_hydrate_after_blank = nil
  storage._tf_slot_build_queue = nil
  BasicHelpers.for_each_player_by_index_asc(function(player)
    if player.valid then
      Cache.get_player_data(player)
      local main_flow = player.gui.top[Enum.UIEnums.GUI.Shared.MAIN_GUI_FLOW]
      if main_flow and main_flow.valid then
        GuiValidation.safe_destroy_frame(main_flow, Enum.GuiEnum.GUI_FRAME.FAVE_BAR)
      end
      fave_bar.enqueue_blank_bar(player, "on_configuration_changed")
    end
  end)
end

function handlers.get_observers_registered_flag()
  return observers_registered_this_session
end

function handlers.set_observers_registered_flag(value)
  observers_registered_this_session = value
end

-- Queue for deferred player initialization
-- Each entry: { player_index = N, is_rejoin = bool }
local _deferred_init_queue = {}

--- True when deferred init is waiting (cheap check before calling process_deferred_init_queue).
---@return boolean
function handlers.has_deferred_init_pending()
  return #_deferred_init_queue > 0
end

--- Process all queued player initializations (drained on on_nth_tick(2), not tick 0).
--- Restricted players (spectator/god) are kept in the queue and retried every 2 ticks
--- until they have a character — handles the MP case where the host is briefly in
--- spectator mode at tick 2 before their character is assigned.
function handlers.process_deferred_init_queue()
  -- Skip tick 0: on_nth_tick(2) also fires at tick 0; defer heavy work until tick 2+.
  if game.tick == 0 then return end
  if #_deferred_init_queue == 0 then return end
  local retry = {}
  for _, entry in ipairs(_deferred_init_queue) do
    local deferred_player = game.players[entry.player_index]
    if deferred_player and deferred_player.valid then
      if BasicHelpers.is_restricted_controller(deferred_player) then
        -- Player is spectator/god — not ready yet. Retry on the next on_nth_tick(2).
        table.insert(retry, entry)
      else
        Cache.reset_transient_player_states(deferred_player)

        if entry.is_rejoin then
          close_all_mod_screens(deferred_player)
          -- Observer cleanup was moved to the on_player_joined_game dispatcher handler
          -- so fresh observers are in place during the 2-tick gap before this runs.
        end

        register_gui_observers(deferred_player)

        -- Force-build: cancels any in-flight progressive build and populates all slots
        -- synchronously (force_show=true bypasses is_planet_surface).
        ErrorHandler.warn_log("[TF_MP][deferred_init] calling fave_bar.build", {
          tick            = game.tick,
          player          = deferred_player.name,
          controller_type = deferred_player.controller_type,
          is_rejoin       = entry.is_rejoin,
        })
        fave_bar.build(deferred_player, true)
      end
    end
  end
  _deferred_init_queue = retry
end

--- Enqueue a player for deferred initialization (deduplicates).
---@param player_index uint
---@param is_rejoin boolean
local function enqueue_deferred_init(player_index, is_rejoin)
  for _, entry in ipairs(_deferred_init_queue) do
    if entry.player_index == player_index then
      if not is_rejoin then
        entry.is_rejoin = false
      end
      return
    end
  end
  table.insert(_deferred_init_queue, { player_index = player_index, is_rejoin = is_rejoin })
end

--- Single-player save load (and adding this mod to a save) does not fire `on_player_joined_game`.
--- Mirror the join path once per session so the fave bar is queued before the next `on_nth_tick(2)`
--- drains `process_deferred_init_queue`.
--- `enqueue_deferred_init(..., true)` dedupes with `on_player_created`/`on_player_joined_game` without
--- overwriting `is_rejoin = false` for brand-new players.
--- `enqueue_blank_bar` matches join/created: chrome + empty slots first, hydrate when ready.
---
--- MP SAFETY: Only enqueue a fresh blank build when no bar is present and no build is already running.
--- In MP catch-up the joining client runs this on its first tick (observers_registered reset by on_load)
--- while the server skips it (flag already true). Calling enqueue_blank_bar unconditionally cancels any
--- in-flight build and inserts a new frame_init entry, causing chrome1 to destroy + recreate FAVE_BAR_FLOW
--- on the client only → GUI state diverges from server → CRC mismatch → desync.
--- process_deferred_init_queue already handles hydration via its own blank_bar_is_ready check.
function handlers.ensure_fave_bar_for_session_players()
  BasicHelpers.for_each_player_by_index_asc(function(player)
    if player and player.valid and BasicHelpers.is_valid_player(player) then
      enqueue_deferred_init(player.index, true)
      local ready = fave_bar.blank_bar_is_ready(player)
      local pending = fave_bar.has_pending_slot_build(player.index)
      if not ready and not pending then
        fave_bar.enqueue_blank_bar(player, "ensure_fave_bar_for_session_players")
      else
        ErrorHandler.warn_log("[TF_MP][ensure_fave_bar_for_session_players] skip enqueue_blank_bar", {
          tick = game.tick,
          player_index = player.index,
          player_name = player.name,
          blank_bar_is_ready = ready,
          has_pending_slot_build = pending,
        })
      end
    end
  end)
end

function handlers.on_player_created(event)
  with_valid_player(event.player_index, function(player)
    enqueue_deferred_init(player.index, false)
    fave_bar.enqueue_blank_bar(player, "on_player_created")
  end)
end

function handlers.on_player_joined_game(event)
  with_valid_player(event.player_index, function(player)
    ErrorHandler.debug_log("Deferring initialization for rejoining player", {
      player = player.name,
      player_index = player.index
    })
    enqueue_deferred_init(player.index, true)
    fave_bar.enqueue_blank_bar(player, "on_player_joined_game")
  end)
end

-- Extend handlers with chart-tag event functions
require("core.events.handlers_chart_tag")(handlers)

return handlers
