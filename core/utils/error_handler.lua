---@diagnostic disable: undefined-global


local Constants = require("constants")
local BasicHelpers = require("core.utils.basic_helpers")
local _in_error_handler = false


local ErrorHandler = {}

local function send_error_to_player(player, error_key)
  if not BasicHelpers.is_valid_player(player) then return end
  local message_text = BasicHelpers.format_error_message(error_key)
  BasicHelpers.safe_player_print(player, message_text)
end

ErrorHandler._log_level = (Constants and Constants.settings and Constants.settings.DEFAULT_LOG_LEVEL) or "production"

function ErrorHandler.is_debug()
  return ErrorHandler._log_level == "debug"
end

function ErrorHandler.should_log_debug()
  return ErrorHandler._log_level == "debug"
end

function ErrorHandler.set_log_level(level)
  if level and (level == "debug" or level == "production" or level == "warn" or level == "error") then
    ErrorHandler._log_level = level
    pcall(function() log("[TeleFaves] Log level set to: " .. tostring(level)) end)
  end
end

function ErrorHandler.initialize(log_level)
  local space = "space"
  ErrorHandler._initialized = true
  if log_level and (log_level == "debug" or log_level == "production" or log_level == "warn" or log_level == "error") then
    ErrorHandler._log_level = log_level
  end
  pcall(function() log("[TeleFaves] Logger initialized. Log level: " .. tostring(ErrorHandler._log_level)) end)
end

function ErrorHandler.debug_log(message, context)
  if not ErrorHandler.is_debug() then return end
  if _in_error_handler then return end
  _in_error_handler = true
  local prefix = "[TeleFaves][DEBUG] "
  local ok, err = pcall(function()
    if context and type(context) == "table" then
      local context_str = ""
      for k, v in pairs(context) do
        context_str = context_str .. tostring(k) .. "=" .. tostring(v) .. " "
      end
      log(prefix .. message .. " | Context: " .. context_str)
    else
      log(prefix .. message)
    end
  end)
  -- Do not attempt to log errors from within the logger itself
  _in_error_handler = false
end

function ErrorHandler.warn_log(message, context)
  if _in_error_handler then return end
  _in_error_handler = true
  local prefix = "[TeleFaves][WARN] "
  local ok, err = pcall(function()
    local context_str = ""
    if context and type(context) == "table" then
      for k, v in pairs(context) do
        context_str = context_str .. tostring(k) .. "=" .. tostring(v) .. " "
      end
      log(prefix .. message .. " | Context: " .. context_str)
    else
      log(prefix .. message)
    end
  end)
  -- Do not attempt to log errors from within the logger itself
  _in_error_handler = false
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
  local context_str = ""
  for k, v in pairs(context) do
    context_str = context_str .. tostring(k) .. "=" .. tostring(v) .. " "
  end
  pcall(function() log(msg .. " | Context: " .. context_str) end)

  -- Show player message for user-facing errors if applicable
  if event and event.player_index then
    local player = game.players[event.player_index]
    if player ~= nil then
      -- Only show generic error message for critical failures
      if event_type and (event_type:find("gui") or event_type:find("input")) then
        send_error_to_player(player, "Event handler error occurred")
      end
    end
  end
end

return ErrorHandler
