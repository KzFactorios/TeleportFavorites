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
- Terrain Events: tile building, mining, terrain changes
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
EventRegistrationDispatcher.register_terrain_events(script)
--]]

local ErrorHandler = require("core.utils.error_handler")
local GameHelpers = require("core.utils.game_helpers")
local Settings = require("core.utils.settings_access")
local fave_bar = require("gui.favorites_bar.fave_bar")
local ChartTagUtils = require("core.utils.chart_tag_utils")

---@class EventRegistrationDispatcher
local EventRegistrationDispatcher = {}

-- Import all required modules
local gui_event_dispatcher = require("core.events.gui_event_dispatcher")
local custom_input_dispatcher = require("core.events.custom_input_dispatcher")
local on_gui_closed_handler = require("core.events.on_gui_closed_handler")
local handlers = require("core.events.handlers")
local control_data_viewer = require("core.control.control_data_viewer")

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
            GameHelpers.player_print(player, {"tf-error.event_handler_error"})
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
          local success, gui_observer = pcall(require, "core.pattern.gui_observer")
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
          -- Import gui_observer safely
          local success, gui_observer = pcall(require, "core.pattern.gui_observer")
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
    },    [defines.events.on_player_left_game] = {
      handler = function(event)
        -- Handle chart tag ownership reset
        local ChartTagOwnershipManager = require("core.control.chart_tag_ownership_manager")
        ChartTagOwnershipManager.on_player_left_game(event)
        
        -- Clean up observers when players leave
        local success, gui_observer = pcall(require, "core.pattern.gui_observer")
        if success and gui_observer.GuiEventBus and gui_observer.GuiEventBus.cleanup_all then
          gui_observer.GuiEventBus.cleanup_all()
        end
      end,
      name = "on_player_left_game"
    },
    [defines.events.on_player_removed] = {
      handler = function(event)
        -- Handle chart tag ownership reset
        local ChartTagOwnershipManager = require("core.control.chart_tag_ownership_manager")
        ChartTagOwnershipManager.on_player_removed(event)
        
        -- Clean up observers when players are removed
        local success, gui_observer = pcall(require, "core.pattern.gui_observer")
        if success and gui_observer.GuiEventBus and gui_observer.GuiEventBus.cleanup_all then
          gui_observer.GuiEventBus.cleanup_all()
        end
      end,
      name = "on_player_removed"
    },[defines.events.on_runtime_mod_setting_changed] = {
      handler = function(event)          -- Handle changes to the favorites on/off setting
        if event.setting == "favorites-on" then
          for _, player in pairs(game.connected_players) do
            local player_settings = Settings:getPlayerSettings(player)
            if player_settings.favorites_on then
              fave_bar.build(player)
            else
              fave_bar.destroy(player)
            end
          end
          return
        end-- Handle changes to the teleport radius
        if event.setting == "teleport-radius" then
          ErrorHandler.debug_log("Teleport radius setting changed", {
            player_index = event.player_index
          })
          return
        end

        -- Handle changes to the destination message setting
        if event.setting == "destination-msg-on" then
          ErrorHandler.debug_log("Destination message setting changed", {
            player_index = event.player_index
          })
          return        end
      end,
      name = "on_runtime_mod_setting_changed"
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

--- Register terrain and chart tag related events
---@param script table The Factorio script object
---@return boolean success
function EventRegistrationDispatcher.register_terrain_events(script)
  if not script or type(script.on_event) ~= "function" then
    ErrorHandler.warn_log("Invalid script object for terrain events registration")
    return false
  end
    ErrorHandler.debug_log("Registering terrain events")
    local success = true
  
  -- Register chart tag terrain protection events (replaces old relocation system)
  local terrain_success = pcall(ChartTagUtils.register_terrain_events, script)
  if not terrain_success then
    ErrorHandler.warn_log("Failed to register terrain protection events through ChartTagUtils")
    success = false
  end
  ErrorHandler.debug_log("Terrain events registration complete", { success = success })
  
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
  results.terrain = EventRegistrationDispatcher.register_terrain_events(script)
  results.observer = EventRegistrationDispatcher.register_observer_events(script)
  results.data_viewer = EventRegistrationDispatcher.register_data_viewer_events(script)
  
  -- Check overall success
  for category, success in pairs(results) do
    if not success then
      overall_success = false
      ErrorHandler.warn_log("Event registration failed for category", { category = category })
    end
  end
  
  ErrorHandler.debug_log("Event registration complete", {
    overall_success = overall_success,
    results = results
  })
  
  return overall_success
end

return EventRegistrationDispatcher
