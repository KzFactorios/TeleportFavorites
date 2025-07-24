---@diagnostic disable: undefined-global


---@class DebugConfig
local DebugConfig = {}

DebugConfig.LEVELS = {
  NONE = 0,
  ERROR = 1,
  WARN = 2,
  INFO = 3,
}

local function detect_environment()
  local is_debug = false
  if script and script.mod_name then
    is_debug = (storage and storage._tf_debug_mode) == true
  end
  return is_debug and DebugConfig.LEVELS.DEBUG or DebugConfig.LEVELS.WARN
end

local current_debug_level = nil

---@return number level Current debug level
function DebugConfig.get_level()
  if not current_debug_level then
    current_debug_level = detect_environment()
  end
  return current_debug_level
end

---@param level number Debug level (use DebugConfig.LEVELS constants)
function DebugConfig.set_level(level)
  if level >= DebugConfig.LEVELS.NONE and level <= DebugConfig.LEVELS.TRACE then
    current_debug_level = level
    DebugConfig.log(DebugConfig.LEVELS.INFO, "Debug level changed", {new_level = level})
  end
end

---@param level number Debug level to check
---@return boolean should_log True if this level should be logged
function DebugConfig.should_log(level)
  if not level then return false end
  if not current_debug_level then
    current_debug_level = detect_environment()
  end
  return level <= current_debug_level
end

---@param level number Debug level
---@param message string Log message
---@param data table? Optional data table
function DebugConfig.log(level, message, data)
  if not DebugConfig.should_log(level) then
    return
  end

  local ErrorHandler = require("core.utils.error_handler")

  local level_names = {
    [DebugConfig.LEVELS.ERROR] = "ERROR",
    [DebugConfig.LEVELS.WARN] = "WARN",
    [DebugConfig.LEVELS.INFO] = "INFO",
    [DebugConfig.LEVELS.DEBUG] = "DEBUG",
    [DebugConfig.LEVELS.TRACE] = "TRACE"
  }

  local level_name = level_names[level] or "UNKNOWN"
  local prefixed_message = "[" .. level_name .. "] " .. message

  if level <= DebugConfig.LEVELS.ERROR then
    ErrorHandler.raise({
      key = "debug.error_level_log",
      default = prefixed_message
    }, data)
  else
    ErrorHandler.debug_log(prefixed_message, data)
  end
end

function DebugConfig.enable_production_mode()
  DebugConfig.set_level(DebugConfig.LEVELS.WARN)
  DebugConfig.log(DebugConfig.LEVELS.INFO, "Production mode enabled")
end

function DebugConfig.enable_debug_mode()
  DebugConfig.set_level(DebugConfig.LEVELS.DEBUG)
  DebugConfig.log(DebugConfig.LEVELS.INFO, "Debug mode enabled")
end

---@param level number? Debug level (current level if nil)
---@return string name Debug level name
function DebugConfig.get_level_name(level)
  level = level or current_debug_level
  local names = {
    [DebugConfig.LEVELS.NONE] = "NONE",
    [DebugConfig.LEVELS.ERROR] = "ERROR",
    [DebugConfig.LEVELS.WARN] = "WARN",
    [DebugConfig.LEVELS.INFO] = "INFO",
    [DebugConfig.LEVELS.DEBUG] = "DEBUG",
    [DebugConfig.LEVELS.TRACE] = "TRACE"
  }
  return names[level] or "UNKNOWN"
end

function DebugConfig.initialize()
  current_debug_level = detect_environment()
  DebugConfig.log(DebugConfig.LEVELS.INFO, "Debug system initialized", {
    level = current_debug_level,
  level_name = DebugConfig.get_level_name(),
  environment = current_debug_level == DebugConfig.LEVELS.DEBUG and "debug" or "production"
  })
end

return DebugConfig
