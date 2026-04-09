---@diagnostic disable: undefined-global

-- core/events/event_registration_dispatcher.lua
-- TeleportFavorites Factorio Mod
-- Centralized event registration dispatcher. All lifecycle, GUI, custom input,
-- modal-blocking, and ownership events are registered here.

local Deps = require("deps")
local ErrorHandler, Cache, Constants, Enum, BasicHelpers =
  Deps.ErrorHandler, Deps.Cache, Deps.Constants, Deps.Enum, Deps.BasicHelpers
local gui_event_dispatcher = require("core.events.gui_event_dispatcher")
local custom_input_dispatcher = require("core.events.custom_input_dispatcher")
local control_tag_editor = require("core.control.control_tag_editor")
local teleport_history_modal = require("gui.teleport_history_modal.teleport_history_modal")
local handlers = require("core.events.handlers")
local DebugCommands = require("core.commands.debug_commands")
local ChartTagUtils = require("core.utils.chart_tag_utils")
local fave_bar = require("gui.favorites_bar.fave_bar")
local tag_editor = require("gui.tag_editor.tag_editor")
local GuiObserver = require("core.events.gui_observer")
local ProfilerExport = require("core.utils.profiler_export")

---@class EventRegistrationDispatcher
local EventRegistrationDispatcher = {}

-- ===========================
-- SHARED HELPER
-- ===========================

local function create_safe_event_handler(handler, handler_name)
  return function(event)
    local success, err = xpcall(function() handler(event) end, debug.traceback)
    if not success then
      ErrorHandler.warn_log("Event handler failed", {
        handler_name = handler_name,
        error = tostring(err),
        player_index = event.player_index
      })
      if event.player_index then
        local player = game.get_player(event.player_index)
        if player and player.valid then
          player.print("[TeleportFavorites] Event handler error occurred: " .. tostring(err))
        end
      end
    end
  end
end

-- ===========================
-- CHART TAG OWNERSHIP MANAGER (from chart_tag_ownership_manager.lua)
-- ===========================

local ChartTagOwnershipManager = {}

local function reset_ownership_for_player(player_name)
  if not player_name or player_name == "" then
    ErrorHandler.warn_log("Cannot reset ownership: invalid player name")
    return 0
  end
  local reset_count = 0
  for _, surface in pairs(game.surfaces) do
    if surface and surface.valid then
      local surface_tags = Cache.get_surface_tags(surface.index)
      if surface_tags then
        for _, tag in pairs(surface_tags) do
          if tag and tag.owner_name == player_name then
            tag.owner_name = nil
            reset_count = reset_count + 1
          end
        end
      end
    end
  end
  return reset_count
end


function ChartTagOwnershipManager.on_player_removed(event)
  local player = game.get_player(event.player_index)
  if not player then
    ErrorHandler.warn_log("Cannot handle player removed: invalid player index", { player_index = event.player_index })
    return
  end
  local player_name = player.name
  local reset_count = reset_ownership_for_player(player_name)
  if reset_count > 0 then
    ErrorHandler.debug_log("Reset chart tag ownership due to player removal", {
      player_name = player_name, reset_count = reset_count
    })
  end
end

-- ===========================
-- MODAL INPUT BLOCKER (from modal_input_blocker.lua)
-- ===========================

local ModalInputBlocker = {}

local function should_block_input(player_index)
  local player = game.players[player_index]
  if not BasicHelpers.is_valid_player(player) then return false end
  return Cache.is_modal_dialog_active(player)
end

local function block_input_event(event, event_name)
  if not event or not event.player_index then return false end
  if should_block_input(event.player_index) then
    ErrorHandler.debug_log("[MODAL BLOCKER] Blocking input event", {
      event_name = event_name,
      player_index = event.player_index,
      modal_type = Cache.get_modal_dialog_type(game.players[event.player_index])
    })
    return true
  end
  return false
end

local function make_blocker(name) return function(event) block_input_event(event, name) end end

local function assert_script(script, context)
  if not script or type(script.on_event) ~= "function" then
    ErrorHandler.warn_log("Invalid script object: " .. (context or "unknown"))
    return false
  end
  return true
end

function ModalInputBlocker.register_handlers(script)
  if not assert_script(script, "modal input blocker") then return false end
  ErrorHandler.debug_log("Registering modal input blocking handlers")
  local events_to_register = {
    {defines.events.on_built_entity,                 make_blocker("on_built_entity")},
    {defines.events.on_pre_player_mined_item,        make_blocker("on_pre_player_mined_item")},
    {defines.events.on_player_mined_item,            make_blocker("on_player_mined_item")},
    {defines.events.on_player_fast_transferred,      make_blocker("on_player_fast_transferred")},
    {defines.events.on_player_selected_area,         make_blocker("on_player_selected_area")},
    {defines.events.on_player_alt_selected_area,     make_blocker("on_player_alt_selected_area")},
    {defines.events.on_player_setup_blueprint,       make_blocker("on_player_setup_blueprint")},
    {defines.events.on_player_configured_blueprint,  make_blocker("on_player_configured_blueprint")},
    {defines.events.on_pre_build,                    make_blocker("on_pre_build")},
    {defines.events.on_player_cursor_stack_changed,  make_blocker("on_player_cursor_stack_changed")},
    {defines.events.on_player_main_inventory_changed,make_blocker("on_player_main_inventory_changed")},
    {defines.events.on_player_deconstructed_area,    make_blocker("on_player_deconstructed_area")},
  }
  for _, event_data in ipairs(events_to_register) do
    script.on_event(event_data[1], event_data[2])
  end
  ErrorHandler.debug_log("Modal input blocking handlers registered successfully")
  return true
end

-- ===========================
-- CORE EVENT REGISTRATION (from event_registration_core.lua)
-- ===========================

local function apply_max_slots_to_player(p)
  local old_max = Cache.get_last_max_favorite_slots(p)
  Cache.Settings.invalidate_player_cache(p)
  local new_max = Cache.Settings.get_player_max_favorite_slots(p)
  Cache.apply_player_max_slots(p, new_max)
  Cache.set_last_max_favorite_slots(p, new_max)
  fave_bar.build(p, true)
  if type(old_max) == "number" and type(new_max) == "number" and new_max < old_max then
    game.print(string.format("[TeleportFavorites] %s set Max Slots to %d. Favorites beyond this new maximum have been permanently deleted.", p.name, new_max))
  end
end

local function register_core_events(script)
  if not assert_script(script, "core events") then return false end

  ErrorHandler.debug_log("Registering core lifecycle events")

  local registration_count = 0

  local core_events = {}
  core_events[defines.events.on_player_created] = {
    handler = function(event)
      handlers.on_player_created(event)
      local player = game.players[event.player_index]
      if player and player.valid then
        local reg_ok, reg_err = pcall(GuiObserver.GuiEventBus.register_player_observers, player)
        if not reg_ok then
          ErrorHandler.warn_log("Failed to register GUI observers for new player", { player = player.name, error = tostring(reg_err) })
        end
      end
    end,
    name = "on_player_created"
  }
  core_events[defines.events.on_player_joined_game] = {
    handler = function(event)
      handlers.on_player_joined_game(event)
      local player = game.players[event.player_index]
      if player and player.valid then
        local player_data = Cache.get_player_data(player)
        if player_data.drag_favorite then
          player_data.drag_favorite.active = false
          player_data.drag_favorite.source_slot = nil
          player_data.drag_favorite.favorite = nil
        end
        if player_data.tag_editor_data and player_data.tag_editor_data.move_mode then
          player_data.tag_editor_data.move_mode = false
          player_data.tag_editor_data.error_message = ""
        end
        pcall(function() player.clear_cursor() end)
        ErrorHandler.debug_log("Transient states reset for rejoining player", {
          player = player.name, player_index = player.index
        })
        local reg_ok, reg_err = pcall(GuiObserver.GuiEventBus.register_player_observers, player)
        if not reg_ok then
          ErrorHandler.warn_log("Failed to register GUI observers for joining player", { player = player.name, error = tostring(reg_err) })
        end
      end
    end,
    name = "on_player_joined_game"
  }
  core_events[defines.events.on_player_changed_surface] = {
    handler = handlers.on_player_changed_surface, name = "on_player_changed_surface"
  }
  core_events[defines.events.on_player_removed] = {
    handler = ChartTagOwnershipManager.on_player_removed,
    name = "on_player_removed"
  }
  core_events[defines.events.on_runtime_mod_setting_changed] = {
    handler = function(event)
      ErrorHandler.debug_log("[SETTINGS] on_runtime_mod_setting_changed fired for setting: " .. tostring(event.setting))
      ErrorHandler.debug_log("[SETTINGS] Event player_index: " .. tostring(event.player_index))
      ErrorHandler.debug_log("[SETTINGS] Event setting_type: " .. tostring(event.setting_type))

      if event.setting == "favorites_on" then
        ErrorHandler.debug_log("[SETTINGS] Processing favorites_on change")
        for _, player in pairs(game.connected_players) do
          Cache.Settings.invalidate_player_cache(player)
          local player_settings = Cache.Settings.get_player_settings(player)
          ErrorHandler.debug_log("[SETTINGS] Player " .. player.name .. " favorites_on: " .. tostring(player_settings.favorites_on))
          fave_bar.build(player, true)
        end
        return
      end

      if event.setting == Constants.settings.MAX_FAVORITE_SLOTS_SETTING then
        ErrorHandler.debug_log("[SETTINGS] Processing max-favorite-slots change")
        local player = (event.player_index and game.players[event.player_index]) or nil
        if player and player.valid then
          apply_max_slots_to_player(player)
        else
          for _, p in pairs(game.connected_players) do
            apply_max_slots_to_player(p)
          end
        end
        return
      end

      if event.setting == "enable_teleport_history" then
        ErrorHandler.debug_log("[SETTINGS] Processing enable_teleport_history change")
        for _, player in pairs(game.connected_players) do
          Cache.Settings.invalidate_player_cache(player)
          local player_settings = Cache.Settings.get_player_settings(player)
          if not player_settings.enable_teleport_history then
            teleport_history_modal.destroy(player)
          end
          fave_bar.build(player, true)
        end
        return
      end

      if event.setting == Constants.settings.SLOT_LABEL_MODE_SETTING then
        ErrorHandler.debug_log("[SETTINGS] Processing slot-label-mode change")
        local player = (event.player_index and game.players[event.player_index]) or nil
        if player and player.valid then
          Cache.Settings.invalidate_player_cache(player)
          fave_bar.build(player, true)
        end
        return
      end

      ErrorHandler.debug_log("[SETTINGS] Unknown setting changed: " .. tostring(event.setting))
    end,
    name = "on_runtime_mod_setting_changed"
  }
  core_events[defines.events.on_player_controller_changed] = {
    handler = fave_bar.on_player_controller_changed, name = "on_player_controller_changed"
  }
  core_events[defines.events.on_chart_tag_added] = {
    handler = handlers.on_chart_tag_added, name = "on_chart_tag_added"
  }
  core_events[defines.events.on_chart_tag_modified] = {
    handler = handlers.on_chart_tag_modified, name = "on_chart_tag_modified"
  }
  core_events[defines.events.on_chart_tag_removed] = {
    handler = handlers.on_chart_tag_removed, name = "on_chart_tag_removed"
  }

  -- Periodic cleanup: GUI observer cleanup (every 30 min) and icon_typing reset (every 15 min)
  local nth_ok, nth_err = pcall(function()
    script.on_nth_tick(108000, function()
      GuiObserver.GuiEventBus.schedule_periodic_cleanup()
    end)
    script.on_nth_tick(54000, function()
      ChartTagUtils.reset_icon_type_lookup()
      ErrorHandler.debug_log("icon_typing table reset (every 15 minutes)")
    end)
    -- GPS point cache sweep: evicts TTL-expired entries for active surfaces only.
    -- Per-surface next_sweep_at clock pauses while no players are on that surface.
    script.on_nth_tick(Cache.Lookups.SWEEP_TICKS, function()
      Cache.Lookups.sweep_expired_entries()
    end)
  end)
  if not nth_ok then
    ErrorHandler.warn_log("Failed to register periodic cleanup or icon_typing reset", { error = nth_err })
  else
    ErrorHandler.debug_log("Registered periodic GUI observer cleanup, icon_typing reset, and GPS cache sweep")
  end

  -- MULTIPLAYER FIX: All on_nth_tick and on_tick handlers are registered permanently.
  -- Dynamic registration/deregistration causes script-event-mismatch when clients join.

  script.on_nth_tick(2, function()
    if GuiObserver.GuiEventBus._deferred_tick_active then
      ProfilerExport.start_section("deferred_notifications")
      GuiObserver.GuiEventBus.process_deferred_notifications()
      ProfilerExport.stop_section("deferred_notifications")
    end
    fave_bar.process_slot_build_queue()
    tag_editor.process_build_queue()
  end)

  script.on_nth_tick(60, function()
    handlers.process_deferred_init_queue()
  end)

  ErrorHandler.debug_log("[EVENT_REG] Registering on_tick handler for first-tick setup")
  script.on_event(defines.events.on_tick, function(event)
    ProfilerExport.on_game_tick(event)
    if not handlers.get_observers_registered_flag() then
      handlers.set_observers_registered_flag(true)
      ErrorHandler.debug_log("[TICK] *** REGISTERING GUI OBSERVERS *** (first tick after load)", { tick = event.tick })
      ProfilerExport.start_section("first_tick_observers")
      for _, player in pairs(game.players) do
        if player and player.valid then
          GuiObserver.GuiEventBus.register_player_observers(player)
          ErrorHandler.debug_log("[TICK] Registered observers for player", {
            player = player.name, player_index = player.index, tick = event.tick
          })
        end
      end
      -- SP save load / mod added to save: no on_player_joined_game — queue fave bar like a rejoin.
      ProfilerExport.start_section("session_fave_bar_init")
      handlers.ensure_fave_bar_for_session_players()
      ProfilerExport.stop_section("session_fave_bar_init")
      -- process_deferred_notifications is intentionally NOT called here.
      -- on_nth_tick(2) drains it at tick 2, keeping tick-0 cost lower.
      ProfilerExport.stop_section("first_tick_observers")
      ErrorHandler.debug_log("[TICK] GUI observers registered for all players", { tick = event.tick })
    end
  end)

  script.on_event(defines.events.on_gui_location_changed, function(event)
    local player = game.players[event.player_index]
    if not player or not player.valid then return end
    local element = event.element
    if element and element.valid and element.name == Enum.GuiEnum.GUI_FRAME.TELEPORT_HISTORY_MODAL then
      local loc = element.location
      if loc and type(loc.x) == "number" and type(loc.y) == "number" then
        Cache.set_history_modal_position(player, { x = loc.x, y = loc.y })
      end
    end
  end)

  for event_type, event_config in pairs(core_events) do
    local safe_handler = create_safe_event_handler(event_config.handler, event_config.name)
    script.on_event(event_type, safe_handler)
    registration_count = registration_count + 1
  end

  ErrorHandler.debug_log("Core events registration complete", { registered = registration_count })
  return true
end

-- ===========================
-- PUBLIC API
-- ===========================

function EventRegistrationDispatcher.register_core_events(script)
  return register_core_events(script)
end

function EventRegistrationDispatcher.register_gui_events(script)
  if not assert_script(script, "GUI events") then return false end

  ErrorHandler.debug_log("Registering GUI events")
  local success = true

  local gui_success = pcall(gui_event_dispatcher.register_gui_handlers, script)
  if not gui_success then
    ErrorHandler.warn_log("Failed to register GUI events through dispatcher")
    success = false
  end

  local closed_handler = create_safe_event_handler(
    function(event)
      control_tag_editor.on_gui_closed(event)
      teleport_history_modal.on_gui_closed(event)
    end,
    "on_gui_closed"
  )

  local closed_success = pcall(function()
    script.on_event(defines.events.on_gui_closed, closed_handler)
  end)

  if not closed_success then
    ErrorHandler.warn_log("Failed to register on_gui_closed handler")
    success = false
  end
  ErrorHandler.debug_log("GUI events registration complete", { success = success })
  return success
end

function EventRegistrationDispatcher.register_custom_input_events(script)
  if not assert_script(script, "custom input events") then return false end

  ErrorHandler.debug_log("Registering custom input events")
  local success = true

  local input_success = pcall(custom_input_dispatcher.register_default_inputs, script)
  if not input_success then
    ErrorHandler.warn_log("Failed to register custom input events through dispatcher")
    success = false
  end

  local tag_editor_handler = create_safe_event_handler(
    handlers.on_open_tag_editor_custom_input, "tf-open-tag-editor"
  )

  local tag_editor_success = pcall(function()
    script.on_event("tf-open-tag-editor", tag_editor_handler)
  end)

  if not tag_editor_success then
    ErrorHandler.warn_log("Failed to register tag editor custom input")
    success = false
  end
  ErrorHandler.debug_log("Custom input events registration complete", { success = success })
  return success
end

function EventRegistrationDispatcher.register_all_events(script)
  if not assert_script(script, "register_all_events") then return false end

  ErrorHandler.debug_log("Starting comprehensive event registration")

  local input_names = {}
  for k, _ in pairs(custom_input_dispatcher.default_custom_input_handlers) do
    table.insert(input_names, k)
  end
  ErrorHandler.debug_log("Custom input event names registered:", { input_names = input_names })

  local results = {}
  local overall_success = true

  results.core = EventRegistrationDispatcher.register_core_events(script)
  results.gui = EventRegistrationDispatcher.register_gui_events(script)
  results.custom_input = EventRegistrationDispatcher.register_custom_input_events(script)
  results.modal_input_blocker = ModalInputBlocker.register_handlers(script)

  local debug_cmd_success, debug_cmd_err = pcall(DebugCommands.register_commands)
  results.debug_commands = debug_cmd_success
  if not debug_cmd_success then
    ErrorHandler.warn_log("Failed to register debug commands", { error = tostring(debug_cmd_err) })
  end

  for category, success in pairs(results) do
    if not success then
      overall_success = false
      ErrorHandler.warn_log("Event registration failed for category", { category = category })
    end
  end

  ErrorHandler.debug_log("Comprehensive event registration complete", { results = results })
  return overall_success
end

return EventRegistrationDispatcher
