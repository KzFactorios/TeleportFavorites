local Deps = require("core.deps_barrel")
local ErrorHandler, Cache, Constants, Enum, BasicHelpers =
  Deps.ErrorHandler, Deps.Cache, Deps.Constants, Deps.Enum, Deps.BasicHelpers
local ControlTagEditor = require("core.control.control_tag_editor")
local GuiValidation = require("core.utils.gui_validation")
local fave_bar = require("gui.favorites_bar.fave_bar")
local teleport_history_modal = require("gui.teleport_history_modal.teleport_history_modal")
local gui_observer = require("core.events.gui_observer")
local FavoriteUtils = require("core.favorite.favorite_utils")
local PlayerFavorites = require("core.favorite.player_favorites")
local with_valid_player = BasicHelpers.with_valid_player
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
local observers_registered_this_session = false
function handlers.on_load()
  ErrorHandler.debug_log("GUI Event Bus ready on game load")
  observers_registered_this_session = false
  ErrorHandler.debug_log("[ON_LOAD] Reset observer registration flag", {
    flag_value = observers_registered_this_session
  })
end
function handlers.on_configuration_changed(data)
  ErrorHandler.debug_log("[CONFIG_CHANGED] Configuration changed, clearing stale fave bars")
  storage._tf_hydrate_after_blank = nil
  BasicHelpers.for_each_player_by_index_asc(function(player)
    if player.valid then
      Cache.get_player_data(player)
      local main_flow = player.gui.top[Enum.UIEnums.GUI.Shared.MAIN_GUI_FLOW]
      if main_flow and main_flow.valid then
        GuiValidation.safe_destroy_frame(main_flow, Enum.GuiEnum.GUI_FRAME.FAVE_BAR)
      end
    end
  end)
end
function handlers.get_observers_registered_flag()
  return observers_registered_this_session
end
function handlers.set_observers_registered_flag(value)
  observers_registered_this_session = value
end
local _deferred_init_queue = {}
local function player_has_nonblank_favorites(player, surface_idx)
  local pfaves = Cache.get_player_favorites(player, surface_idx)
  if not pfaves then return false end
  for i = 1, #pfaves do
    local fav = pfaves[i]
    if fav and not FavoriteUtils.is_blank_favorite(fav) then return true end
  end
  return false
end
function handlers.has_deferred_init_pending()
  return #_deferred_init_queue > 0
end
function handlers.process_deferred_init_queue()
  if game.tick == 0 then return end
  if #_deferred_init_queue == 0 then return end
  for _, entry in ipairs(_deferred_init_queue) do
    local deferred_player = game.players[entry.player_index]
    if deferred_player and deferred_player.valid then
      Cache.reset_transient_player_states(deferred_player)
      if entry.is_rejoin then
        close_all_mod_screens(deferred_player)
        gui_observer.GuiEventBus.cleanup_player_observers(deferred_player)
      end
      register_gui_observers(deferred_player)
      if entry.is_rejoin then
        local surface_idx = deferred_player.surface.index
        local has_favorites = player_has_nonblank_favorites(deferred_player, surface_idx)
        if fave_bar.blank_bar_is_ready(deferred_player) then
          if has_favorites then
            fave_bar.enqueue_hydrate(deferred_player)
          end
        elseif fave_bar.has_pending_slot_build(deferred_player.index) then
          if has_favorites then
            storage._tf_hydrate_after_blank = storage._tf_hydrate_after_blank or {}
            storage._tf_hydrate_after_blank[deferred_player.index] = true
          end
        else
          fave_bar.enqueue_progressive_build(deferred_player)
        end
      end
    end
  end
  _deferred_init_queue = {}
end
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
require("core.events.handlers_chart_tag")(handlers)
return handlers
