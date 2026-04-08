---@diagnostic disable: undefined-global

-- core/events/handlers.lua
-- TeleportFavorites Factorio Mod
-- Centralized event handler implementations for TeleportFavorites.
-- Chart-tag handlers live in handlers_chart_tag.lua (extend pattern).

local Deps = require("deps")
local ErrorHandler, Cache, Constants, Enum, BasicHelpers =
  Deps.ErrorHandler, Deps.Cache, Deps.Constants, Deps.Enum, Deps.BasicHelpers
local ControlTagEditor = require("core.control.control_tag_editor")
local GuiValidation = require("core.utils.gui_validation")
local fave_bar = require("gui.favorites_bar.fave_bar")
local teleport_history_modal = require("gui.teleport_history_modal.teleport_history_modal")
local gui_observer = require("core.events.gui_observer")
local ProfilerExport = require("core.utils.profiler_export")
local FavoriteUtils = require("core.favorite.favorite_utils")
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
  ProfilerExport.start_section("cache_init")
  Cache.init()
  ProfilerExport.stop_section("cache_init")

  ProfilerExport.start_section("player_observer_setup")
  for _, player in pairs(game.players) do
    register_gui_observers(player)
  end
  ProfilerExport.stop_section("player_observer_setup")

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
  for _, player in pairs(game.players) do
    if player.valid then
      Cache.get_player_data(player)
      local main_flow = player.gui.top[Enum.UIEnums.GUI.Shared.MAIN_GUI_FLOW]
      if main_flow and main_flow.valid then
        GuiValidation.safe_destroy_frame(main_flow, Enum.GuiEnum.GUI_FRAME.FAVE_BAR)
      end
    end
  end
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

--- Process all queued player initializations
--- on_nth_tick(60) stays permanently registered for multiplayer safety; it no-ops when queue is empty
function handlers.process_deferred_init_queue()
  -- Skip tick 0: on_nth_tick(60) fires on tick 0 (0 % 60 == 0) before any player input is
  -- visible, and the GUI API costs here would spike the very first frame.
  if game.tick == 0 then return end
  if #_deferred_init_queue == 0 then return end
  for _, entry in ipairs(_deferred_init_queue) do
    local deferred_player = game.players[entry.player_index]
    if deferred_player and deferred_player.valid then
      ProfilerExport.start_section("deferred_cache_reset")
      Cache.reset_transient_player_states(deferred_player)
      ProfilerExport.stop_section("deferred_cache_reset")

      ProfilerExport.start_section("deferred_close_screens")
      if entry.is_rejoin then
        close_all_mod_screens(deferred_player)
        gui_observer.GuiEventBus.cleanup_player_observers(deferred_player)
      end
      ProfilerExport.stop_section("deferred_close_screens")

      ProfilerExport.start_section("deferred_register_observers")
      register_gui_observers(deferred_player)
      ProfilerExport.stop_section("deferred_register_observers")

      -- The blank bar was pre-built by enqueue_blank_bar (called in on_player_joined/created).
      -- Skip hydration when there is nothing to fill in:
      --   • is_rejoin=false  → brand-new player, no favorites exist yet
      --   • no non-blank favorites on the current surface → blank bar is already correct
      ProfilerExport.start_section("fave_bar_build")
      if not entry.is_rejoin then
        ProfilerExport.stop_section("fave_bar_build")
      elseif fave_bar.blank_bar_is_ready(deferred_player) then
        local surface_idx = deferred_player.surface.index
        local pfaves = Cache.get_player_favorites(deferred_player, surface_idx)
        local has_favorites = false
        if pfaves then
          for _, fav in pairs(pfaves) do
            if not FavoriteUtils.is_blank_favorite(fav) then
              has_favorites = true
              break
            end
          end
        end
        if has_favorites then
          fave_bar.enqueue_hydrate(deferred_player)
        end
        ProfilerExport.stop_section("fave_bar_build")
      else
        fave_bar.enqueue_progressive_build(deferred_player)
        ProfilerExport.stop_section("fave_bar_build")
      end
    end
  end
  _deferred_init_queue = {}
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

function handlers.on_player_created(event)
  with_valid_player(event.player_index, function(player)
    enqueue_deferred_init(player.index, false)
    fave_bar.enqueue_blank_bar(player)
  end)
end

function handlers.on_player_joined_game(event)
  with_valid_player(event.player_index, function(player)
    ErrorHandler.debug_log("Deferring initialization for rejoining player", {
      player = player.name,
      player_index = player.index
    })
    enqueue_deferred_init(player.index, true)
    fave_bar.enqueue_blank_bar(player)
  end)
end

-- Extend handlers with chart-tag event functions
require("core.events.handlers_chart_tag")(handlers)

return handlers
