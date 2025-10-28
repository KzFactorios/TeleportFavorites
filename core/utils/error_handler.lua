---@diagnostic disable: undefined-global

pcall(function() log("[TeleFaves] error_handler.lua loading...") end)


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

-- Auto-detect debug mode based on path
local function is_debug_path()
  -- Check if we're in a development/debug directory
  local debug_paths = {"2_Gemini", "debug", "dev", "development"}
  local current_file = debug.getinfo(1, "S").source
  if current_file then
    pcall(function() log("[TeleFaves] Auto-detecting debug path from: " .. tostring(current_file)) end)
    for _, path in ipairs(debug_paths) do
      if current_file:find(path) then
        pcall(function() log("[TeleFaves] Found debug path: " .. path .. " in " .. current_file) end)
        return true
      end
    end
  end
  pcall(function() log("[TeleFaves] No debug path detected") end)
  return false
end

if is_debug_path() then
  ErrorHandler._log_level = "debug"
  pcall(function() log("[TeleFaves] Auto-set log level to debug due to path") end)
end

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
  local old_level = ErrorHandler._log_level
  pcall(function() log("[TeleFaves] Initialize called with log_level: " .. tostring(log_level)) end)
  if log_level and (log_level == "debug" or log_level == "production" or log_level == "warn" or log_level == "error") then
    ErrorHandler._log_level = log_level
  end
  pcall(function() 
    log("[TeleFaves] Logger initialized. Log level changed from '" .. tostring(old_level) .. "' to '" .. tostring(ErrorHandler._log_level) .. "'")
    if ErrorHandler._log_level == "debug" then
      log("[TeleFaves][DEBUG] Debug logging is ENABLED")
    end
  end)
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
