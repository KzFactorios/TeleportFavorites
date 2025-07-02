---@diagnostic disable: undefined-global

--[[
event_registration_dispatcher.lua
TeleportFavorites Factorio Mod
-----------------------------
Centralized event registration dispatcher for all mod events.

Features:
---------
- Single point of registration for ALL mod events
- Consistent error handling and logging patterns
- Safe handler wrappers with comprehensive validation
- Unified registration API for different event types
- Automatic cleanup and validation of event handlers
- Performance optimized registration with batch operations

Architecture:
-------------
- Consolidates mixed registration patterns into single dispatcher
- Provides safe wrapper functions for all event handlers
- Implements standardized error handling across all events
- Maintains separation of concerns while centralizing registration
- Supports both GUI events and game events through unified interface

Supported Event Categories:
---------------------------
- Core Events: player lifecycle, mod lifecycle, surface changes
- GUI Events: clicks, text changes, element changes, confirmations
- Custom Input Events: keyboard shortcuts and key bindings
- Chart Events: tag creation, modification, removal
- Observer Events: player join/leave, cleanup operations

Event Handler Requirements:
---------------------------
All event handlers must follow these patterns:
- Accept single event parameter
- Perform player validation if applicable
- Use ErrorHandler for logging
- Return gracefully on invalid conditions
- No global state modifications without proper validation

Usage:
------
-- Register all events for the mod
EventRegistrationDispatcher.register_all_events(script)

-- Register specific event categories
EventRegistrationDispatcher.register_core_events(script)
EventRegistrationDispatcher.register_gui_events(script)
--]]

local ErrorHandler = require("core.utils.error_handler")
local GameHelpers = require("core.utils.game_helpers")
local Settings = require("core.utils.settings_access")
local fave_bar = require("gui.favorites_bar.fave_bar")
local Cache = require("core.cache.cache")
local gui_event_dispatcher = require("core.events.gui_event_dispatcher")
local custom_input_dispatcher = require("core.events.custom_input_dispatcher")
local on_gui_closed_handler = require("core.events.on_gui_closed_handler")
local handlers = require("core.events.handlers")
local control_data_viewer = require("core.control.control_data_viewer")

local fave_bar_gui_labels_manager = require("core.control.fave_bar_gui_labels_manager")


---@class EventRegistrationDispatcher
local EventRegistrationDispatcher = {}

-- Track registration state (use rawget to avoid static analysis issues)
local _registration_state = {}

--- Create a safe wrapper for event handlers with comprehensive error handling
---@param handler function The event handler function
---@param handler_name string Name for logging and debugging
---@param event_type string Type of event (for context)
---@return function Safe wrapper function
local function create_safe_event_handler(handler, handler_name, event_type)
  return function(event)
    local success, err = pcall(handler, event)
    if not success then
      ErrorHandler.warn_log("Event handler failed: " .. handler_name .. " - " .. tostring(err), {
        handler = handler_name,
        event_type = event_type,
        error = err,
        player_index = event and event.player_index
      })
      -- Show player message for user-facing errors if applicable
      if event and event.player_index then
        local player = game.get_player(event.player_index)
        if player and player.valid then
          -- Only show generic error message for critical failures
          if event_type:find("gui") or event_type:find("input") then
            GameHelpers.player_print(player, { "tf-error.event_handler_error" })
          end
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

  -- Core lifecycle events
  local core_events = {
    [defines.events.on_player_created] = {
      handler = function(event)
        handlers.on_player_created(event)
        -- Also setup observers for new players
        local player = game.get_player(event.player_index)
        if player and player.valid then
          -- Import gui_observer safely
          local success, gui_observer = pcall(require, "core.events.gui_observer")
          if success and gui_observer.GuiEventBus and gui_observer.GuiEventBus.register_player_observers then
            gui_observer.GuiEventBus.register_player_observers(player)
          end
        end
      end,
      name = "on_player_created"
    },
    [defines.events.on_player_joined_game] = {
      handler = function(event)
        handlers.on_player_created(event)
        -- Also setup observers for joined players
        local player = game.get_player(event.player_index)
        if player and player.valid then
          -- Reset transient states for rejoining players
          -- This handles cases where cleanup on leave may have failed
          local player_data = Cache.get_player_data(player)

          -- Reset drag mode state
          if player_data.drag_favorite then
            player_data.drag_favorite.active = false
            player_data.drag_favorite.source_slot = nil
            player_data.drag_favorite.favorite = nil
          end

          -- Reset move mode state
          if player_data.tag_editor_data and player_data.tag_editor_data.move_mode then
            player_data.tag_editor_data.move_mode = false
            player_data.tag_editor_data.error_message = ""
          end

          -- Clear cursor
          pcall(function()
            player.clear_cursor()
          end)

          ErrorHandler.debug_log("Transient states reset for rejoining player", {
            player = player.name,
            player_index = player.index
          })

          -- Import gui_observer safely
          local success, gui_observer = pcall(require, "core.events.gui_observer")
          if success and gui_observer.GuiEventBus and gui_observer.GuiEventBus.register_player_observers then
            gui_observer.GuiEventBus.register_player_observers(player)
          end
        end
      end,
      name = "on_player_joined_game"
    },
    [defines.events.on_player_changed_surface] = {
      handler = handlers.on_player_changed_surface,
      name = "on_player_changed_surface"
    },
    [defines.events.on_player_left_game] = {
      handler = function(event)
        -- Get the leaving player before handling chart tag ownership
        local leaving_player = game.get_player(event.player_index)
        local ErrorHandler = require("core.utils.error_handler")

        -- Handle chart tag ownership reset
        local ChartTagOwnershipManager = require("core.control.chart_tag_ownership_manager")
        ChartTagOwnershipManager.on_player_left_game(event)

        -- Reset drag mode and move mode states for leaving player
        if leaving_player and leaving_player.valid then
          -- Reset drag mode state
          local Cache = require("core.cache.cache")
          local player_data = Cache.get_player_data(leaving_player)
          if player_data and player_data.drag_favorite and player_data.drag_favorite.active then
            local CursorUtils = require("core.utils.cursor_utils")
            CursorUtils.end_drag_favorite(leaving_player)
          end

          -- Reset move mode state and clear cursor
          pcall(function()
            leaving_player.clear_cursor()
          end)

          -- Reset any tag editor move mode states
          local tag_data = Cache.get_tag_editor_data(leaving_player)
          -- Check if move_mode exists and is true (move_mode is dynamically set)
          local move_mode_active = tag_data.move_mode
          if move_mode_active then
            tag_data.move_mode = false
            Cache.set_tag_editor_data(leaving_player, tag_data)
          end

          -- Clear any error messages to prevent persistence across sessions
          tag_data.error_message = ""
          Cache.set_tag_editor_data(leaving_player, tag_data)
        end

        -- Enhanced cleanup for leaving player using targeted methods
        local success, gui_observer = pcall(require, "core.events.gui_observer")
        if success and gui_observer.GuiEventBus then
          if leaving_player and leaving_player.valid and gui_observer.GuiEventBus.cleanup_player_observers then
            -- Use targeted player cleanup
            gui_observer.GuiEventBus.cleanup_player_observers(leaving_player)
          elseif gui_observer.GuiEventBus.cleanup_disconnected_player_observers then
            -- Use disconnected player cleanup if player is no longer valid
            gui_observer.GuiEventBus.cleanup_disconnected_player_observers(event.player_index)
          elseif gui_observer.GuiEventBus.cleanup_all then
            -- Final fallback to global cleanup
            gui_observer.GuiEventBus.cleanup_all()
          end
        end
      end,
      name = "on_player_left_game"
    },
    [defines.events.on_player_removed] = {
      handler = function(event)
        -- Get the removed player before handling chart tag ownership
        local removed_player = game.get_player(event.player_index)
        local ErrorHandler = require("core.utils.error_handler")

        -- Handle chart tag ownership reset
        local ChartTagOwnershipManager = require("core.control.chart_tag_ownership_manager")
        ChartTagOwnershipManager.on_player_removed(event)

        -- Reset drag mode and move mode states for removed player
        if removed_player and removed_player.valid then
          -- Reset drag mode state
          local Cache = require("core.cache.cache")
          local player_data = Cache.get_player_data(removed_player)
          if player_data and player_data.drag_favorite and player_data.drag_favorite.active then
            local CursorUtils = require("core.utils.cursor_utils")
            CursorUtils.end_drag_favorite(removed_player)
          end

          -- Reset move mode state and clear cursor
          pcall(function()
            removed_player.clear_cursor()
          end)

          -- Reset any tag editor move mode states
          local tag_data = Cache.get_tag_editor_data(removed_player)
          -- Check if move_mode exists and is true (move_mode is dynamically set)
          local move_mode_active = tag_data.move_mode
          if move_mode_active then
            tag_data.move_mode = false
            Cache.set_tag_editor_data(removed_player, tag_data)
          end

          -- Clear any error messages to prevent persistence across sessions
          tag_data.error_message = ""
          Cache.set_tag_editor_data(removed_player, tag_data)
        end

        -- Enhanced cleanup for removed player using targeted methods
        local success, gui_observer = pcall(require, "core.events.gui_observer")
        if success and gui_observer.GuiEventBus then
          if removed_player and removed_player.valid and gui_observer.GuiEventBus.cleanup_player_observers then
            -- Use targeted player cleanup
            gui_observer.GuiEventBus.cleanup_player_observers(removed_player)
          elseif gui_observer.GuiEventBus.cleanup_disconnected_player_observers then
            -- Use disconnected player cleanup if player is no longer valid
            gui_observer.GuiEventBus.cleanup_disconnected_player_observers(event.player_index)
          elseif gui_observer.GuiEventBus.cleanup_all then
            -- Final fallback to global cleanup
            gui_observer.GuiEventBus.cleanup_all()
          end
        end
      end,
      name = "on_player_removed"
    },
    [defines.events.on_runtime_mod_setting_changed] = {
      handler = function(event) -- Handle changes to the favorites on/off setting
        if event.setting == "favorites-on" then
          for _, player in pairs(game.connected_players) do
            local player_settings = Settings:getPlayerSettings(player)
            if player_settings.favorites_on then
              fave_bar.build(player, true) -- Force show when enabling setting
            else
              fave_bar.destroy(player)
            end
          end
          return
        end

        -- Destination message setting has been removed - messages always shown
      end,
      name = "on_runtime_mod_setting_changed"
    },
    [defines.events.on_player_controller_changed] = {
      handler = function(event)
        if not event or not event.player_index then return end
        local player = game.get_player(event.player_index)
        if not player or not player.valid then return end
        
        -- Always try to rebuild the bar when controller changes
        -- The build function will handle space platform and other restrictions
        fave_bar.build(player)
      end,
      name = "on_player_controller_changed"
    },
    -- Chart tag events - Critical: These were missing!
    [defines.events.on_chart_tag_added] = {
      handler = handlers.on_chart_tag_added,
      name = "on_chart_tag_added"
    },
    [defines.events.on_chart_tag_modified] = {
      handler = handlers.on_chart_tag_modified,
      name = "on_chart_tag_modified"
    },
    [defines.events.on_chart_tag_removed] = {
      handler = handlers.on_chart_tag_removed,
      name = "on_chart_tag_removed"
    }
  }

  -- Add scheduled GUI observer cleanup (every 5 minutes = 18000 ticks)
  local success, err = pcall(function()
    script.on_nth_tick(18000, function(event)
      local gui_observer_success, gui_observer = pcall(require, "core.events.gui_observer")
      if gui_observer_success and gui_observer.GuiEventBus and gui_observer.GuiEventBus.schedule_periodic_cleanup then
        gui_observer.GuiEventBus.schedule_periodic_cleanup()
      end
    end)
  end)

  if not success then
    ErrorHandler.warn_log("Failed to register periodic GUI observer cleanup", { error = err })
  else
    ErrorHandler.debug_log("Registered periodic GUI observer cleanup (every 5 minutes)")
  end

  -- Register each core event with safety wrapper
  for event_type, event_config in pairs(core_events) do
    local safe_handler = create_safe_event_handler(
      event_config.handler,
      event_config.name,
      "core_event"
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
    on_gui_closed_handler.on_gui_closed,
    "on_gui_closed",
    "gui_event"
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
    "tf-open-tag-editor",
    "custom_input"
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

  -- Register observer for favorites bar updates
  local GuiObserver = require("core.events.gui_observer")
  local GuiEventBus = GuiObserver.GuiEventBus
  
  -- Create a simple observer function for favorites bar updates
  local favorites_bar_observer = {
    update = function(self, event_data)
      ErrorHandler.debug_log("[FAVORITES_BAR] Observer triggered", {
        event_data = event_data,
        player = event_data.player and event_data.player.name or "nil",
        action = event_data.action or "unknown"
      })
      
      if event_data.player and event_data.player.valid then
        local fave_bar = require("gui.favorites_bar.fave_bar")
        local GuiHelpers = require("core.utils.gui_helpers")
        local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(event_data.player)
        if main_flow then
          ErrorHandler.debug_log("[FAVORITES_BAR] Updating slot row for player", {
            player = event_data.player.name,
            gps = event_data.gps or "unknown"
          })
          -- Update the slot row to reflect the new favorite
          fave_bar.update_slot_row(event_data.player, main_flow)
        else
          ErrorHandler.debug_log("[FAVORITES_BAR] Main flow not found for player", {
            player = event_data.player.name
          })
        end
      else
        ErrorHandler.debug_log("[FAVORITES_BAR] Invalid player in event data")
      end
    end
  }
  
  -- Subscribe to the favorites_bar_updated event
  ErrorHandler.debug_log("[OBSERVER] Registering favorites_bar_updated observer")
  GuiEventBus.subscribe("favorites_bar_updated", favorites_bar_observer)
  ErrorHandler.debug_log("[OBSERVER] favorites_bar_updated observer registered successfully")

  ErrorHandler.debug_log("Observer events registration complete")

  return true
end

--- Register data viewer events (specialized control module)
---@param script table The Factorio script object
---@return boolean success
function EventRegistrationDispatcher.register_data_viewer_events(script)
  if not script or type(script.on_event) ~= "function" then
    ErrorHandler.warn_log("Invalid script object for data viewer events registration")
    return false
  end

  local success = pcall(control_data_viewer.register, script)
  if not success then
    ErrorHandler.warn_log("Failed to register data viewer events")
    return false
  end

  ErrorHandler.debug_log("Data viewer events registration complete")
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

  local results = {}
  local overall_success = true

  -- Register in dependency order
  results.core = EventRegistrationDispatcher.register_core_events(script)
  results.gui = EventRegistrationDispatcher.register_gui_events(script)
  results.custom_input = EventRegistrationDispatcher.register_custom_input_events(script)
  results.observer = EventRegistrationDispatcher.register_observer_events(script)
  results.data_viewer = EventRegistrationDispatcher.register_data_viewer_events(script)
  

  -- Register all favorites bar GUI label updaters and controls
  fave_bar_gui_labels_manager.register_all(script)
  results.fave_bar_gui_labels = true

  -- Check overall success
  for category, success in pairs(results) do
    if not success then
      overall_success = false
      ErrorHandler.warn_log("Event registration failed for category", { category = category })
    end
  end

  return overall_success
end

return EventRegistrationDispatcher
