---@diagnostic disable: undefined-global

-- core/utils/error_handler.lua
-- TeleportFavorites Factorio Mod
-- Centralized error handling for consistent reporting, logging, and error propagation.
-- Provides error type categorization, debug logging, and safe error bubbling.

local BasicHelpers = require("core.utils.basic_helpers")

-- Prevent infinite recursion in error handling
local _in_error_handler = false

---@class ErrorResult
---@field error_type string?
---@field context table?

local ErrorHandler = {}

--- Local helper to send error messages to players (breaks circular dependency with PlayerHelpers)
---@param player LuaPlayer The player to send message to
---@param error_key string Error message
local function send_error_to_player(player, error_key)
    if not BasicHelpers.is_valid_player(player) then return end
    local message_text = "[TeleportFavorites] " .. error_key
    pcall(function() player.print(message_text) end)
end

--- Set the log level for the mod ('production', 'debug', etc.)
ErrorHandler._log_level = "production"

---Initialize the logging system (debug/production mode, multiplayer-safe)
function ErrorHandler.initialize(log_level)
  ErrorHandler._initialized = true
  if log_level then
    ErrorHandler._log_level = log_level
  else
    -- Optionally, detect from remote or settings
    ErrorHandler._log_level = (remote and remote.interfaces and remote.interfaces.TeleportFavorites_Debug) and "debug" or
    "production"
  end
  pcall(function() log("[TeleFaves] Logger initialized. Log level: " .. tostring(ErrorHandler._log_level)) end)
end

--- Debug logging helper
---@param message string
---@param context table?
function ErrorHandler.debug_log(message, context)
  if ErrorHandler._log_level ~= "debug" then return end
  if _in_error_handler then return end
  _in_error_handler = true
  local prefix = "[TeleFaves][DEBUG] "
  if context and type(context) == "table" then
    local context_str = ""
    for k, v in pairs(context) do
      context_str = context_str .. tostring(k) .. "=" .. tostring(v) .. " "
    end
    pcall(function() log(prefix .. message .. " | Context: " .. context_str) end)
  else
    pcall(function() log(prefix .. message) end)
  end
  _in_error_handler = false
end

--- Warning logging helper
---@param message string
---@param context table?
function ErrorHandler.warn_log(message, context)
  if _in_error_handler then return end
  _in_error_handler = true
  local prefix = "[TeleFaves][WARN] "
  local context_str = ""
  if context and type(context) == "table" then
    for k, v in pairs(context) do
      context_str = context_str .. tostring(k) .. "=" .. tostring(v) .. " "
    end
    pcall(function() log(prefix .. message .. " | Context: " .. context_str) end)
  else
    pcall(function() log(prefix .. message) end)
  end
  _in_error_handler = false
end

--- Log unexpected/critical errors with consistent formatting and optional player messaging
---@param handler_name string Name of the handler that failed
---@param error string Error message
---@param event table Event object (may contain player_index)
---@param event_type string? Type of event for additional context
function ErrorHandler.error_log(handler_name, error, event, event_type)
  local prefix = "[TeleFaves][ERROR] "
  local msg = prefix .. "Critical error in handler: " .. handler_name .. " - " .. tostring(error)
  local context = {
    handler = handler_name,
    event_type = event_type or "unknown",
    error = error,
    player_index = event and event.player_index
  }
  if context then
    local context_str = ""
    for k, v in pairs(context) do
      context_str = context_str .. tostring(k) .. "=" .. tostring(v) .. " "
    end
    pcall(function() log(msg .. " | Context: " .. context_str) end)
  else
    pcall(function() log(msg) end)
  end

  -- Show player message for user-facing errors if applicable
  if event and event.player_index then
    local player = game.players[event.player_index]
    if BasicHelpers.is_valid_player(player) then
      -- Only show generic error message for critical failures
      if event_type and (event_type:find("gui") or event_type:find("input")) then
        send_error_to_player(player --[[@as LuaPlayer]], "Event handler error occurred")
      end
    end
  end
end

return ErrorHandler
