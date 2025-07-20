

-- core/utils/error_handler.lua
-- TeleportFavorites Factorio Mod
-- Centralized error handling for consistent reporting, logging, and error propagation.
-- Provides error type categorization, debug logging, and safe error bubbling.

---@diagnostic disable: undefined-global

-- Prevent infinite recursion in error handling
local _in_error_handler = false

---@class ErrorResult
---@field error_type string?
---@field context table?

local ErrorHandler = {}

ErrorHandler.ERROR_TYPES = {
  VALIDATION_FAILED = "validation_failed",
  CHART_TAG_FAILED = "chart_tag_failed",
  MISSING_DEPENDENCY = "missing_dependency",
  FACTORIO_API_ERROR = "factorio_api_error"
}

---Initialize the logging system (debug/production mode, multiplayer-safe)
function ErrorHandler.initialize()
  -- Example: Set up debug/production mode flag, or hook into Factorio log system
  ErrorHandler._initialized = true
  ErrorHandler._debug_mode = (remote and remote.interfaces and remote.interfaces.TeleportFavorites_Debug) or false
  -- Optionally, log initialization
  pcall(function() log("[TeleportFavorites] Logger initialized. Debug mode: " .. tostring(ErrorHandler._debug_mode)) end)
end

--- Info logging helper
---@param message string
---@param context table?
function ErrorHandler.info(message, context)
  if _in_error_handler then return end
  _in_error_handler = true
  if context and type(context) == "table" then
    local context_str = ""
    for k, v in pairs(context) do
      context_str = context_str .. tostring(k) .. "=" .. tostring(v) .. " "
    end
    pcall(function() log("[TeleportFavorites] INFO: " .. message .. " | Context: " .. context_str) end)
  else
    pcall(function() log("[TeleportFavorites] INFO: " .. message) end)
  end
  _in_error_handler = false
end

--- Debug logging helper
---@param message string
---@param context table?
function ErrorHandler.debug_log(message, context)
  if _in_error_handler then return end
  _in_error_handler = true
    if context and type(context) == "table" then
    local context_str = ""
    for k, v in pairs(context) do
      context_str = context_str .. tostring(k) .. "=" .. tostring(v) .. " "
    end
    pcall(function() log("[TeleportFavorites] DEBUG: " .. message .. " | Context: " .. context_str) end)
  else
    pcall(function() log("[TeleportFavorites] DEBUG: " .. message) end)
  end
  
  _in_error_handler = false
end

--- Warning logging helper  
---@param message string
---@param context table?
function ErrorHandler.warn_log(message, context)
  if _in_error_handler then return end
  _in_error_handler = true
  local context_str = ""
  if context and type(context) == "table" then
    for k, v in pairs(context) do
      context_str = context_str .. tostring(k) .. "=" .. tostring(v) .. " "
    end
    pcall(function() log("[TeleportFavorites] WARNING: " .. message .. " | Context: " .. context_str) end)
  else
    pcall(function() log("[TeleportFavorites] WARNING: " .. message) end)
  end
  _in_error_handler = false
end

--- Log event handler errors with consistent formatting and optional player messaging
---@param handler_name string Name of the handler that failed
---@param error string Error message
---@param event table Event object (may contain player_index)
---@param event_type string? Type of event for additional context
function ErrorHandler.log_event_error(handler_name, error, event, event_type)
  ErrorHandler.warn_log("Event handler failed: " .. handler_name .. " - " .. tostring(error), {
    handler = handler_name,
    event_type = event_type or "unknown",
    error = error,
    player_index = event and event.player_index
  })

  -- Show player message for user-facing errors if applicable
  if event and event.player_index then
    local player = game.players[event.player_index]
    local BasicHelpers = require("core.utils.basic_helpers")
    local PlayerHelpers = require("core.utils.player_helpers")
    if BasicHelpers.is_valid_player(player) then
      -- Only show generic error message for critical failures
      if event_type and (event_type:find("gui") or event_type:find("input")) then
        PlayerHelpers.error_message_to_player(player --[[@as LuaPlayer]], "Event handler error occurred", { event_type = event_type })
      end
    end
  end
end

return ErrorHandler
