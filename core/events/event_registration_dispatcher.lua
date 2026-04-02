---@diagnostic disable: undefined-global

-- core/events/event_registration_dispatcher.lua
-- TeleportFavorites Factorio Mod
-- Centralized event registration dispatcher for all mod events, with safe wrappers and unified API.


local ErrorHandler = require("core.utils.error_handler")
local Constants = require("constants")
local icon_typing = require("core.cache.icon_typing")
local Cache = require("core.cache.cache")
local gui_event_dispatcher = require("core.events.gui_event_dispatcher")
local custom_input_dispatcher = require("core.events.custom_input_dispatcher")
local fave_bar = require("gui.favorites_bar.fave_bar")
local control_tag_editor = require("core.control.control_tag_editor")
local teleport_history_modal = require("gui.teleport_history_modal.teleport_history_modal")
local handlers = require("core.events.handlers")
local GuiHelpers = require("core.utils.gui_helpers")
-- REMOVED: ModalInputBlocker was causing UPS spikes by registering 12 high-frequency
-- event handlers (on_built_entity, on_player_mined_item, etc.) that fired on every
-- build/mine/transfer. The handlers were no-ops (Factorio events can't be cancelled).
-- local ModalInputBlocker = require("core.events.modal_input_blocker")
local GuiValidation = require("core.utils.gui_validation")
local Enum = require("prototypes.enums.enum")
local ChartTagOwnershipManager = require("core.control.chart_tag_ownership_manager")

local GuiObserver = require("core.events.gui_observer")
local DebugCommands = require("core.commands.debug_commands")

---@class EventRegistrationDispatcher
local EventRegistrationDispatcher = {}

-- Track registration state (use rawget to avoid static analysis issues)
local _registration_state = {}


--- Create a safe wrapper for event handlers (using centralized helper)
--- UPS OPTIMIZATION: Inline debug check to avoid debug_log function call overhead on every event
local function create_safe_event_handler(handler, handler_name)
  return function(event)
    if ErrorHandler.should_log_debug() then
      ErrorHandler.debug_log("Event received", {
        handler_name = handler_name,
        player_index = event.player_index,
        event_type = event.name
      })
    end

    local success, err = xpcall(function() handler(event) end, debug.traceback)
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
      ErrorHandler.debug_log("[SETTINGS] on_runtime_mod_setting_changed fired for setting: " .. tostring(event.setting))
      ErrorHandler.debug_log("[SETTINGS] Event player_index: " .. tostring(event.player_index))
      ErrorHandler.debug_log("[SETTINGS] Event setting_type: " .. tostring(event.setting_type))

  if event.setting == "favorites_on" then
        ErrorHandler.debug_log("[SETTINGS] Processing favorites_on change")
        for _, player in pairs(game.connected_players) do
          -- Invalidate cache first to ensure we get fresh settings
          Cache.Settings.invalidate_player_cache(player)
          local player_settings = Cache.Settings.get_player_settings(player)
          ErrorHandler.debug_log("[SETTINGS] Player " ..
            player.name .. " favorites_on: " .. tostring(player_settings.favorites_on))

          -- Always rebuild the bar to update visibility - don't destroy it completely
          -- The build function handles showing/hiding specific elements based on settings
          fave_bar.build(player, true) -- Force rebuild to update element visibility
          ErrorHandler.debug_log("[SETTINGS] Rebuilt favorites bar for player " ..
            player.name .. " (favorites_on: " .. tostring(player_settings.favorites_on) .. ")")
        end
        ErrorHandler.debug_log("[SETTINGS] favorites_on processing complete")
        return
      end

      -- Handle per-player max favorite slots change
      if event.setting == Constants.settings.MAX_FAVORITE_SLOTS_SETTING then
        ErrorHandler.debug_log("[SETTINGS] Processing max-favorite-slots change")
        local player = (event.player_index and game.players[event.player_index]) or nil
        if player and player.valid then
          -- Invalidate cache and compute old vs new (old from persistent, new from settings)
          local old_max = Cache.get_last_max_favorite_slots(player)
          Cache.Settings.invalidate_player_cache(player)
          local new_max = Cache.Settings.get_player_max_favorite_slots(player)
          ErrorHandler.debug_log("[SETTINGS] old_max vs new_max", { player = player.name, old_max = old_max, new_max = new_max })
          -- Apply changes
          Cache.apply_player_max_slots(player, new_max)
          -- Persist last known value
          Cache.set_last_max_favorite_slots(player, new_max)
          -- Rebuild favorites bar for this player only
          fave_bar.build(player, true)
          -- If decreased, inform via game.print (global message per requirement)
          if type(old_max) == "number" and type(new_max) == "number" and new_max < old_max then
            local msg = string.format("[TeleportFavorites] %s set Max Slots to %d. Favorites beyond this new maximum have been permanently deleted.", player.name, new_max)
            game.print(msg)
          end
        else
          -- No specific player in event; fallback to all connected players to be safe
          for _, p in pairs(game.connected_players) do
            local old_max = Cache.get_last_max_favorite_slots(p)
            Cache.Settings.invalidate_player_cache(p)
            local new_max = Cache.Settings.get_player_max_favorite_slots(p)
            Cache.apply_player_max_slots(p, new_max)
            Cache.set_last_max_favorite_slots(p, new_max)
            fave_bar.build(p, true)
            if type(old_max) == "number" and type(new_max) == "number" and new_max < old_max then
              local msg = string.format("[TeleportFavorites] %s set Max Slots to %d. Favorites beyond this new maximum have been permanently deleted.", p.name, new_max)
              game.print(msg)
            end
          end
        end
        return
      end
  if event.setting == "enable_teleport_history" then
        ErrorHandler.debug_log("[SETTINGS] Processing enable_teleport_history change")
        for _, player in pairs(game.connected_players) do
          -- Invalidate cache first to ensure we get fresh settings
          Cache.Settings.invalidate_player_cache(player)
          local player_settings = Cache.Settings.get_player_settings(player)
          ErrorHandler.debug_log("[SETTINGS] Player " ..
            player.name .. " enable_teleport_history: " .. tostring(player_settings.enable_teleport_history))

          -- If teleport history is being disabled, close any open modal
          if not player_settings.enable_teleport_history then
            teleport_history_modal.destroy(player)
            ErrorHandler.debug_log("[SETTINGS] Closed teleport history modal for player " .. player.name)
          end

          -- Rebuild the favorites bar to reflect the new teleport history setting
          fave_bar.build(player, true)
          ErrorHandler.debug_log("[SETTINGS] Rebuilt favorites bar for teleport history change for player " ..
            player.name)
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
          ErrorHandler.debug_log("[SETTINGS] Rebuilt favorites bar for slot-label-mode change for player " .. player.name)
        end
        return
      end

      -- Destination message setting has been removed - messages always shown
      ErrorHandler.debug_log("[SETTINGS] Unknown setting changed: " .. tostring(event.setting))
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

    -- UPS OPTIMIZATION: Removed periodic icon_typing cache reset.
    -- The icon_type_lookup table is non-persistent (lives in _G), so it auto-clears on
    -- game restart/mod reload. Mods can't change mid-game without a restart, and
    -- on_configuration_changed already handles mod updates. The periodic reset was
    -- causing prototype scan storms (240-3000 lookups) on the next bar rebuild.
    -- (Previously: on_nth_tick(54000) calling icon_typing.reset_icon_type_lookup())
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
  
  -- Permanent on_nth_tick(2): Processes deferred GUI notifications when queue has items
  script.on_nth_tick(2, function()
    if GuiObserver.GuiEventBus._deferred_tick_active then
      GuiObserver.GuiEventBus.process_deferred_notifications()
    end
  end)
  
  -- UPS OPTIMIZATION: Eliminated on_tick handler (was 60 no-op dispatches/sec). Observer registration
  -- now happens at tick 60 instead of tick 1. The 1-second delay is fine because the fave bar isn't
  -- built until tick 60 anyway (deferred init), so there's nothing to observe before then.
  script.on_nth_tick(60, function()
    -- First-session observer registration (replaces the removed on_tick handler)
    if not handlers.get_observers_registered_flag() then
      handlers.set_observers_registered_flag(true)
      for _, player in pairs(game.players) do
        if player and player.valid then
          GuiObserver.GuiEventBus.register_player_observers(player)
        end
      end
      GuiObserver.GuiEventBus.process_deferred_notifications()
    end
    handlers.process_deferred_init_queue()
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


  -- REMOVED: Duplicate favorites_bar_observer subscription that was causing double rebuilds
  -- The DataObserver in gui_observer.lua already handles favorite_added/favorite_removed
  -- by rebuilding the favorites bar. Having two observers rebuild the same GUI creates
  -- non-deterministic state and causes multiplayer desyncs.
  -- 
  -- The favorites bar is now rebuilt ONLY by DataObserver when favorite_added or
  -- favorite_removed events are fired.
  
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
  -- REMOVED: Modal input blocker registration (UPS optimization)
  -- results.modal_input_blocker = ModalInputBlocker.register_handlers(script)
  
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
