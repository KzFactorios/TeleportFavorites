---@diagnostic disable: undefined-global

-- core/events/event_registration_dispatcher.lua
-- TeleportFavorites Factorio Mod
-- Centralized event registration dispatcher for all mod events, with safe wrappers and unified API.


local ErrorHandler = require("core.utils.error_handler")
local Constants = require("constants")
local IconUtils = require("core.cache.icon_utils")
local Cache = require("core.cache.cache")
local gui_event_dispatcher = require("core.events.gui_event_dispatcher")
local custom_input_dispatcher = require("core.events.custom_input_dispatcher")
local fave_bar = require("gui.favorites_bar.fave_bar")
local control_tag_editor = require("core.control.control_tag_editor")
local teleport_history_modal = require("gui.teleport_history_modal.teleport_history_modal")
local handlers = require("core.events.handlers")
local GuiHelpers = require("core.utils.gui_helpers")
local GuiValidation = require("core.utils.gui_validation")
local Enum = require("prototypes.enums.enum")
local ChartTagOwnershipManager = require("core.control.chart_tag_ownership_manager")

local GuiObserver = require("core.events.gui_observer")
local DebugCommands = require("core.commands.debug_commands")

---@class EventRegistrationDispatcher
local EventRegistrationDispatcher = {}

-- Track registration state (use rawget to avoid static analysis issues)
local _registration_state = {}

--[[
---@param phase string
---@param context table|nil

 Completely disabled for test noise reduction
local function log_startup_scheduler_phase(phase, context)
  -- if not ErrorHandler.should_log_debug() then return end
  -- local log_context = context or {}
  -- log_context.tick = game and game.tick or 0
  -- ErrorHandler.debug_log("[STARTUP_SCHEDULER] " .. phase, log_context)
end
]]

---@param event_player_index uint|nil
---@return LuaPlayer[]
local function get_setting_target_players(event_player_index)
  if event_player_index then
    local player = game.players[event_player_index]
    if player then
      return { player }
    end
    return {}
  end
  return game.connected_players
end


--- Create a safe wrapper for event handlers (using centralized helper)
--- UPS OPTIMIZATION: Inline debug check to avoid debug_log function call overhead on every event
local function create_safe_event_handler(handler, handler_name)
  return function(event)
    local success, err = pcall(handler, event)

    if not success then
      ErrorHandler.warn_log("Event handler failed", {
        handler_name = handler_name,
        error = tostring(err),
        stack_trace = debug.traceback(),
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

--- Register core lifecycle and player events
---@param script table The Factorio script object
---@return boolean success
function EventRegistrationDispatcher.register_core_events(script)
  if not script or type(script.on_event) ~= "function" then
    ErrorHandler.warn_log("Invalid script object for core events registration")
    return false
  end

  ErrorHandler.debug_log("Registering core lifecycle events")

  local registration_count = 0
  local error_count = 0

  local core_events = {}
  core_events[defines.events.on_player_created] = {
    handler = function(event)
      -- Observer registration is handled by the deferred init queue (process_deferred_init_queue)
      handlers.on_player_created(event)
    end,
    name = "on_player_created"
  }
  core_events[defines.events.on_player_joined_game] = {
    handler = function(event)
      -- State resets and observer registration are handled by the deferred init queue
      -- (process_deferred_init_queue calls reset_transient_player_states + register_gui_observers)
      handlers.on_player_joined_game(event)
    end,
    name = "on_player_joined_game"
  }
  core_events[defines.events.on_player_changed_surface] = {
    handler = handlers.on_player_changed_surface,
    name = "on_player_changed_surface"
  }
  core_events[defines.events.on_player_left_game] = {
    handler = function(event)
      -- Get the leaving player before handling chart tag ownership
      local leaving_player = game.players[event.player_index]

      ChartTagOwnershipManager.on_player_left_game(event)
    end,
    name = "on_player_left_game"
  }
  core_events[defines.events.on_player_removed] = {
    handler = function(event)
      -- Get the removed player before handling chart tag ownership
      local removed_player = game.players[event.player_index]

      -- Handle chart tag ownership reset
      ChartTagOwnershipManager.on_player_removed(event)
    end,
    name = "on_player_removed"
  }
  core_events[defines.events.on_runtime_mod_setting_changed] = {
    handler = function(event) -- Handle changes to the favorites on/off setting
      if ErrorHandler.should_log_debug() then
        ErrorHandler.debug_log("[SETTINGS] on_runtime_mod_setting_changed fired for setting: " .. tostring(event.setting))
        ErrorHandler.debug_log("[SETTINGS] Event player_index: " .. tostring(event.player_index))
        ErrorHandler.debug_log("[SETTINGS] Event setting_type: " .. tostring(event.setting_type))
      end

    if event.setting == "favorites_on" then
        ErrorHandler.debug_log("[SETTINGS] Processing favorites_on change")
      local target_players = get_setting_target_players(event.player_index)
      for _, player in pairs(target_players) do
          -- Invalidate cache first to ensure we get fresh settings
          Cache.Settings.invalidate_player_cache(player)
          local player_settings = Cache.Settings.get_player_settings(player)
          if ErrorHandler.should_log_debug() then
            ErrorHandler.debug_log("[SETTINGS] Player " ..
              player.name .. " favorites_on: " .. tostring(player_settings.favorites_on))
          end

          -- Always rebuild the bar to update visibility - don't destroy it completely
          -- The build function handles showing/hiding specific elements based on settings
          fave_bar.build(player, true) -- Force rebuild to update element visibility
          if ErrorHandler.should_log_debug() then
            ErrorHandler.debug_log("[SETTINGS] Rebuilt favorites bar for player " ..
              player.name .. " (favorites_on: " .. tostring(player_settings.favorites_on) .. ")")
          end
        end
        ErrorHandler.debug_log("[SETTINGS] favorites_on processing complete")
        return
      end

      -- Handle per-player max favorite slots change
      if event.setting == Constants.settings.MAX_FAVORITE_SLOTS_SETTING then
        ErrorHandler.debug_log("[SETTINGS] Processing max-favorite-slots change")
        local target_players = get_setting_target_players(event.player_index)
        for _, player in pairs(target_players) do
          local old_max = Cache.get_last_max_favorite_slots(player)
          Cache.Settings.invalidate_player_cache(player)
          local new_max = Cache.Settings.get_player_max_favorite_slots(player)
          if ErrorHandler.should_log_debug() then
            ErrorHandler.debug_log("[SETTINGS] old_max vs new_max", { player = player.name, old_max = old_max, new_max = new_max })
          end
          Cache.apply_player_max_slots(player, new_max)
          Cache.set_last_max_favorite_slots(player, new_max)
          fave_bar.build(player, true)
          if type(old_max) == "number" and type(new_max) == "number" and new_max < old_max then
            local msg = string.format("[TeleportFavorites] %s set Max Slots to %d. Favorites beyond this new maximum have been permanently deleted.", player.name, new_max)
            game.print(msg)
          end
        end
        return
      end
      if event.setting == "enable_teleport_history" then
        ErrorHandler.debug_log("[SETTINGS] Processing enable_teleport_history change")
        local target_players = get_setting_target_players(event.player_index)
        for _, player in pairs(target_players) do
          -- Invalidate cache first to ensure we get fresh settings
          Cache.Settings.invalidate_player_cache(player)
          local player_settings = Cache.Settings.get_player_settings(player)
          if ErrorHandler.should_log_debug() then
            ErrorHandler.debug_log("[SETTINGS] Player " ..
              player.name .. " enable_teleport_history: " .. tostring(player_settings.enable_teleport_history))
          end

          -- If teleport history is being disabled, close any open modal
          if not player_settings.enable_teleport_history then
            teleport_history_modal.destroy(player)
            if ErrorHandler.should_log_debug() then
              ErrorHandler.debug_log("[SETTINGS] Closed teleport history modal for player " .. player.name)
            end
          end

          -- Rebuild the favorites bar to reflect the new teleport history setting
          fave_bar.build(player, true)
          if ErrorHandler.should_log_debug() then
            ErrorHandler.debug_log("[SETTINGS] Rebuilt favorites bar for teleport history change for player " ..
              player.name)
          end
        end
        ErrorHandler.debug_log("[SETTINGS] enable_teleport_history processing complete")
        return
      end

      -- Handle slot label mode change — rebuild fave bar to add/remove labels
      if event.setting == Constants.settings.SLOT_LABEL_MODE_SETTING then
        ErrorHandler.debug_log("[SETTINGS] Processing slot-label-mode change")
        local player = (event.player_index and game.players[event.player_index]) or nil
        if player and player.valid then
          Cache.Settings.invalidate_player_cache(player)
          fave_bar.build(player, true)
          if ErrorHandler.should_log_debug() then
            ErrorHandler.debug_log("[SETTINGS] Rebuilt favorites bar for slot-label-mode change for player " .. player.name)
          end
        end
        return
      end

      -- Destination message setting has been removed - messages always shown
      if ErrorHandler.should_log_debug() then
        ErrorHandler.debug_log("[SETTINGS] Unknown setting changed: " .. tostring(event.setting))
      end
    end,
    name = "on_runtime_mod_setting_changed"
  }
  core_events[defines.events.on_player_controller_changed] = {
    handler = fave_bar.on_player_controller_changed,
    name = "on_player_controller_changed"
  }
  -- Chart tag events - Critical: These were missing!
  core_events[defines.events.on_chart_tag_added] = {
    handler = handlers.on_chart_tag_added,
    name = "on_chart_tag_added"
  }
  core_events[defines.events.on_chart_tag_modified] = {
    handler = handlers.on_chart_tag_modified,
    name = "on_chart_tag_modified"
  }
  core_events[defines.events.on_chart_tag_removed] = {
    handler = handlers.on_chart_tag_removed,
    name = "on_chart_tag_removed"
  }

  -- Add scheduled GUI observer cleanup (every 30 minutes = 108000 ticks instead of 5 minutes)
  -- OPTIMIZATION: Reduced frequency to minimize UPS spikes - observers are relatively stable
  local success, err = pcall(function()
    script.on_nth_tick(108000, function(event)
      GuiObserver.GuiEventBus.schedule_periodic_cleanup()
    end)

    -- UPS OPTIMIZATION: Removed periodic IconUtils cache reset.
    -- The icon type lookup table is non-persistent (lives in _G), so it auto-clears on
    -- game restart/mod reload. Mods can't change mid-game without a restart, and
    -- on_configuration_changed already handles mod updates. The periodic reset was
    -- causing prototype scan storms (240-3000 lookups) on the next bar rebuild.
    -- (Previously: on_nth_tick(54000) calling IconUtils.reset_icon_type_lookup())
  end)

  if not success then
    ErrorHandler.warn_log(
      "Failed to register periodic GUI observer cleanup",
      { error = err })
  else
    ErrorHandler.debug_log(
      "Registered periodic GUI observer cleanup (every 30 minutes)")
  end
  
  -- MULTIPLAYER FIX: All on_nth_tick handlers are registered permanently.
  -- Dynamic registration/deregistration at runtime causes script-event-mismatch when clients join.
  -- Each handler uses a flag guard to no-op when inactive (negligible UPS cost).
  
  -- Permanent on_nth_tick(2): fast startup/update loop.
  -- Handles deferred GUI notifications, deferred init, and chunked startup slot hydration.
  script.on_nth_tick(2, function()
    local bootstrapped_this_tick = false

    -- First-session observer registration (replaces removed on_tick handler)
    if not handlers.get_observers_registered_flag() then
      -- log_startup_scheduler_phase("bootstrap.begin")
      handlers.set_observers_registered_flag(true)
      -- Ensure loaded-session players run through deferred init/build path.
      -- on_player_joined_game may not fire for already connected players after save load.
      -- Observer registration is intentionally deferred per-player to avoid startup spikes.
      handlers.enqueue_all_players_for_deferred_init()
      bootstrapped_this_tick = true
      -- log_startup_scheduler_phase("bootstrap.end")
    end

    if GuiObserver.GuiEventBus._deferred_tick_active then
      -- log_startup_scheduler_phase("gui_observer.deferred_notifications.begin")
      GuiObserver.GuiEventBus.process_deferred_notifications()
      -- log_startup_scheduler_phase("gui_observer.deferred_notifications.end")
    end

    -- Avoid combining first-session bootstrap enqueue with deferred queue processing
    -- on the same tick; this smooths the startup peak.
    if bootstrapped_this_tick then
      return
    end

    -- Avoid stacking deferred-init work and slot hydration in the same tick.
    -- This lowers startup peak while keeping slot hydration frequent once init settles.
    local deferred_phase = handlers.process_deferred_init_queue()
    -- log_startup_scheduler_phase("deferred_phase", { phase = deferred_phase })
    if deferred_phase == false or deferred_phase == "build" then
      -- log_startup_scheduler_phase("startup_slot_queue.begin")
      fave_bar.process_startup_slot_build_queue()
      -- log_startup_scheduler_phase("startup_slot_queue.end")
    end
  end)
  
  -- Register on_gui_location_changed for modal position saving
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

  -- Register each core event with safety wrapper
  for event_type, event_config in pairs(core_events) do
    local safe_handler = create_safe_event_handler(
      event_config.handler,
      event_config.name
    )

    local success, err = pcall(function()
      script.on_event(event_type, safe_handler)
    end)

    if success then
      registration_count = registration_count + 1
      ErrorHandler.debug_log("Registered core event", { event = event_config.name })
    else
      error_count = error_count + 1
      ErrorHandler.warn_log("Failed to register core event", {
        event = event_config.name,
        error = err
      })
    end
  end
  ErrorHandler.debug_log("Core events registration complete", {
    registered = registration_count,
    errors = error_count
  })

  return error_count == 0
end

--- Register GUI-related events through centralized dispatcher
---@param script table The Factorio script object
---@return boolean success
function EventRegistrationDispatcher.register_gui_events(script)
  if not script or type(script.on_event) ~= "function" then
    ErrorHandler.warn_log("Invalid script object for GUI events registration")
    return false
  end

  ErrorHandler.debug_log("Registering GUI events")

  local success = true

  -- Register through centralized GUI dispatcher
  local gui_success = pcall(gui_event_dispatcher.register_gui_handlers, script)
  if not gui_success then
    ErrorHandler.warn_log("Failed to register GUI events through dispatcher")
    success = false
  end

  -- Register GUI closed handler for ESC key support
  local closed_handler = create_safe_event_handler(
    function(event)
      -- Try tag editor close first
      control_tag_editor.on_gui_closed(event)
      -- Try teleport history modal close
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

--- Register custom input (keyboard shortcut) events
---@param script table The Factorio script object
---@return boolean success
function EventRegistrationDispatcher.register_custom_input_events(script)
  if not script or type(script.on_event) ~= "function" then
    ErrorHandler.warn_log("Invalid script object for custom input events registration")
    return false
  end

  ErrorHandler.debug_log("Registering custom input events")

  local success = true

  -- Register default custom inputs through dispatcher
  local input_success = pcall(custom_input_dispatcher.register_default_inputs, script)
  if not input_success then
    ErrorHandler.warn_log("Failed to register custom input events through dispatcher")
    success = false
  end

  -- Register custom tag editor input
  local tag_editor_handler = create_safe_event_handler(
    handlers.on_open_tag_editor_custom_input,
    "tf-open-tag-editor"
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

--- Register observer lifecycle events
---@param script table The Factorio script object
---@return boolean success
function EventRegistrationDispatcher.register_observer_events(script)
  if not script or type(script.on_event) ~= "function" then
    ErrorHandler.warn_log("Invalid script object for observer events registration")
    return false
  end


  
  ErrorHandler.debug_log("Observer events registration complete (using DataObserver only)")

  return true
end

--- Register all mod events in proper order
---@param script table The Factorio script object
---@return boolean success True if all registrations succeeded
function EventRegistrationDispatcher.register_all_events(script)
  if not script or type(script.on_event) ~= "function" then
    ErrorHandler.warn_log("Invalid script object provided to register_all_events")
    return false
  end

  ErrorHandler.debug_log("Starting comprehensive event registration")

  local input_names = {}
  for k, _ in pairs(custom_input_dispatcher.default_custom_input_handlers) do
    table.insert(input_names, k)
  end
  ErrorHandler.debug_log("Custom input event names registered:", { input_names = input_names })

  local results = {}
  local overall_success = true

  -- Register in dependency order
  results.core = EventRegistrationDispatcher.register_core_events(script)
  results.gui = EventRegistrationDispatcher.register_gui_events(script)
  results.custom_input = EventRegistrationDispatcher.register_custom_input_events(script)
  results.observer = EventRegistrationDispatcher.register_observer_events(script)
  
  
  -- Register debug commands
  local debug_cmd_success, debug_cmd_err = pcall(DebugCommands.register_commands)
  results.debug_commands = debug_cmd_success
  if not debug_cmd_success then
    ErrorHandler.warn_log("Failed to register debug commands", { error = tostring(debug_cmd_err) })
  end

  -- Check overall success
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
