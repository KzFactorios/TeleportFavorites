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
      fave_bar.build(player, true, true)
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
      fave_bar.build(player, true, true)
    end
  end)
end

function handlers.get_observers_registered_flag()
  return observers_registered_this_session
end

function handlers.set_observers_registered_flag(value)
  observers_registered_this_session = value
end

--- SP save-load and mod-added-to-save paths do not fire `on_player_joined_game`.
--- Called once per session from the first on_tick to cover those cases.
--- In MP the bar will already be built (on_player_joined_game runs before on_tick),
--- so the ready/pending guard ensures nothing is double-built.
function handlers.ensure_fave_bar_for_session_players()
  BasicHelpers.for_each_player_by_index_asc(function(player)
    if not BasicHelpers.is_valid_player(player) then return end
    if BasicHelpers.is_restricted_controller(player) then return end
    local ready   = fave_bar.blank_bar_is_ready(player)
    local pending = fave_bar.has_pending_slot_build(player.index)
    if not ready and not pending then
      fave_bar.build(player, true, true)
    end
  end)
end

function handlers.on_player_created(event)
  with_valid_player(event.player_index, function(player)
    register_gui_observers(player)
  end)
end

function handlers.on_player_joined_game(event)
  with_valid_player(event.player_index, function(player)
    close_all_mod_screens(player)
    Cache.reset_transient_player_states(player)
    pcall(function() player.clear_cursor() end)
    gui_observer.GuiEventBus.cleanup_player_observers(player)
    register_gui_observers(player)
    fave_bar.build(player, true, true)
  end)
end

-- Extend handlers with chart-tag event functions
require("core.events.handlers_chart_tag")(handlers)

return handlers
