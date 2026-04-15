local Constants = require("core.constants_impl")
local BasicHelpers = require("core.utils.basic_helpers")
local _in_error_handler = false
local ErrorHandler = {}
local VALID_LEVELS = { debug = true, production = true, warn = true, error = true }
local function send_error_to_player(player, error_key)
  if not BasicHelpers.is_valid_player(player) then return end
  local message_text = BasicHelpers.format_error_message(error_key)
  BasicHelpers.safe_player_print(player, message_text)
end
ErrorHandler._log_level = (Constants and Constants.settings and Constants.settings.DEFAULT_LOG_LEVEL) or "production"
function ErrorHandler.is_debug()
  return ErrorHandler._log_level == "debug"
end
ErrorHandler.should_log_debug = ErrorHandler.is_debug
function ErrorHandler.set_log_level(level)
  if level and VALID_LEVELS[level] then
    ErrorHandler._log_level = level
    if ErrorHandler.is_debug() then
      pcall(function() log("[TeleFaves] Log level set to: " .. tostring(level)) end)
    end
  end
end
function ErrorHandler.initialize(log_level)
  if log_level and VALID_LEVELS[log_level] then
    ErrorHandler._log_level = log_level
  end
  if ErrorHandler.is_debug() then
    pcall(function()
      log("[TeleFaves][DEBUG] Logger initialized with log level: " .. tostring(ErrorHandler._log_level))
    end)
  end
end
local function emit_log(prefix, message, context, require_debug)
  if require_debug and not ErrorHandler.is_debug() then return end
  if _in_error_handler then return end
  _in_error_handler = true
  pcall(function()
    if context and type(context) == "table" then
      local s = ""
      for k, v in pairs(context) do s = s .. tostring(k) .. "=" .. tostring(v) .. " " end
      log(prefix .. message .. " | Context: " .. s)
    else
      log(prefix .. message)
    end
  end)
  _in_error_handler = false
end
function ErrorHandler.debug_log(message, context)
  emit_log("[TeleFaves][DEBUG] ", message, context, true)
end
function ErrorHandler.warn_log(message, context)
  emit_log("[TeleFaves][WARN] ", message, context, false)
end
function ErrorHandler.error_log(handler_name, error, event, event_type)
  local prefix = "[TeleFaves][ERROR] "
  local msg = prefix .. "Critical error in handler: " .. handler_name .. " - " .. tostring(error)
  local context = {
    handler = handler_name,
    event_type = event_type or "unknown",
    error = error,
    player_index = event and event.player_index
  }
  emit_log("", msg, context, false)
  if event and event.player_index then
    local player = game.players[event.player_index]
    if player ~= nil then
      if event_type and (event_type:find("gui") or event_type:find("input")) then
        send_error_to_player(player, "Event handler error occurred")
      end
    end
  end
end
return ErrorHandler
