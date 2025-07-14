--[[
core/utils/event_handler_helpers.lua
TeleportFavorites Factorio Mod
-----------------------------
Centralized event handler utilities for consistent error handling and player validation.

This module consolidates common patterns used across event handlers:
- Safe event handler wrappers with error handling
- Player validation helpers  
- Error logging and user messaging
- Performance-conscious validation patterns

Usage:
------
local EventHandlerHelpers = require("core.utils.event_handler_helpers")

-- Create safe handler wrapper
local safe_handler = EventHandlerHelpers.create_safe_handler(my_handler, "my_handler", "gui")

-- Validate player and run logic
EventHandlerHelpers.with_valid_player(event.player_index, function(player)
  -- Handler logic here
end)

-- Log event errors with context
EventHandlerHelpers.log_event_error("handler_name", error, event)
]]

local ErrorHandler = require("core.utils.error_handler")
local BasicHelpers = require("core.utils.basic_helpers")

---@class EventHandlerHelpers
local EventHandlerHelpers = {}

--- Validate player and run handler logic with early return pattern
---@param player_index number Player index from event
---@param handler_fn function Function to call with validated player
---@param ... any Additional arguments to pass to handler
---@return any Result from handler function, or nil if player invalid
function EventHandlerHelpers.with_valid_player(player_index, handler_fn, ...)
  if not player_index then return nil end
  local player = game.players[player_index]
  if not BasicHelpers.is_valid_player(player) then return nil end
  return handler_fn(player, ...)
end

--- Create a safe wrapper for event handlers with comprehensive error handling
---@param handler function The event handler function
---@param handler_name string Name for logging and debugging
---@param event_type string Type of event (for context)
---@return function Safe wrapper function
function EventHandlerHelpers.create_safe_handler(handler, handler_name, event_type)
  return function(event)
    local success, err = pcall(handler, event)
    if not success then
      EventHandlerHelpers.log_event_error(handler_name, tostring(err), event, event_type)
    end
  end
end

--- Log event handler errors with consistent formatting and optional player messaging
---@param handler_name string Name of the handler that failed
---@param error string Error message
---@param event table Event object (may contain player_index)
---@param event_type string? Type of event for additional context
function EventHandlerHelpers.log_event_error(handler_name, error, event, event_type)
  ErrorHandler.warn_log("Event handler failed: " .. handler_name .. " - " .. tostring(error), {
    handler = handler_name,
    event_type = event_type or "unknown",
    error = error,
    player_index = event and event.player_index
  })
  
  -- Show player message for user-facing errors if applicable
  if event and event.player_index then
    local player = game.players[event.player_index]
    if BasicHelpers.is_valid_player(player) then
      -- Only show generic error message for critical failures
      if event_type and (event_type:find("gui") or event_type:find("input")) then
        local PlayerHelpers = require("core.utils.player_helpers")
        PlayerHelpers.error_message_to_player(player --[[@as LuaPlayer]], "Event handler error occurred", { event_type = event_type })
      end
    end
  end
end

--- Log debug information for event processing with consistent formatting
---@param handler_name string Name of the handler
---@param message string Debug message
---@param event table Event object
---@param additional_data table? Additional context data
function EventHandlerHelpers.log_event_debug(handler_name, message, event, additional_data)
  local debug_data = {
    handler = handler_name,
    player_index = event and event.player_index,
    event_type = event and event.name
  }
  
  if additional_data then
    for k, v in pairs(additional_data) do
      debug_data[k] = v
    end
  end
  
  ErrorHandler.debug_log(message, debug_data)
end

--- Validate event has required fields before processing
---@param event table Event object to validate
---@param required_fields string[] List of required field names
---@return boolean is_valid True if all required fields are present
function EventHandlerHelpers.validate_event_fields(event, required_fields)
  if not event or type(event) ~= "table" then return false end
  
  for _, field in ipairs(required_fields) do
    if event[field] == nil then
      return false
    end
  end
  
  return true
end

--- Create a debug log wrapper that includes event context
---@param handler_name string Handler name for context
---@return function Debug logging function that includes handler context
function EventHandlerHelpers.create_event_logger(handler_name)
  return function(message, event, additional_data)
    EventHandlerHelpers.log_event_debug(handler_name, message, event, additional_data)
  end
end

return EventHandlerHelpers
