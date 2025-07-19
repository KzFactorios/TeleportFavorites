

-- core/utils/debug_config.lua
-- TeleportFavorites Factorio Mod
-- Centralized debug level management for logging verbosity and debug features.
-- Detects environment, allows runtime adjustment, integrates with ErrorHandler.

---@class DebugConfig
local DebugConfig = {}

-- Debug levels (from least to most verbose)
DebugConfig.LEVELS = {
  NONE = 0,
  ERROR = 1,
  WARN = 2,
  INFO = 3,
  DEBUG = 4,
  TRACE = 5
}

-- Default debug level based on environment detection
local function detect_environment()
  -- Check for development indicators
  local is_development = false
  
  -- Look for development-only files/modules
  local dev_indicators = {
    "tests/validate_syntax.lua",
    ".project/TODO.md", 
    ".scripts/",
    ".github/"
  }
  
  -- In Factorio, we can't directly check file existence, so we use other indicators
  -- Check if debug constants or development settings exist
  if script and script.mod_name then
    -- Look for development-specific storage variables or settings
    is_development = (storage and storage._tf_debug_mode) == true
  end
  
  return is_development and DebugConfig.LEVELS.DEBUG or DebugConfig.LEVELS.WARN
end

-- Current debug level (initialized based on environment)
local current_debug_level = nil

--- Get the current debug level
---@return number level Current debug level
function DebugConfig.get_level()
  if not current_debug_level then
    current_debug_level = detect_environment()
  end
  return current_debug_level
end

--- Set the debug level
---@param level number Debug level (use DebugConfig.LEVELS constants)
function DebugConfig.set_level(level)
  if level >= DebugConfig.LEVELS.NONE and level <= DebugConfig.LEVELS.TRACE then
    current_debug_level = level
    DebugConfig.log(DebugConfig.LEVELS.INFO, "Debug level changed", {new_level = level})
  end
end

--- Check if a given debug level should be logged
---@param level number Debug level to check
---@return boolean should_log True if this level should be logged
function DebugConfig.should_log(level)
  if not level then return false end
  if not current_debug_level then
    current_debug_level = detect_environment()
  end
  return level <= current_debug_level
end

--- Log a message at the specified debug level
---@param level number Debug level
---@param message string Log message
---@param data table? Optional data table
function DebugConfig.log(level, message, data)
  -- Early return for performance - don't process if level too high
  if not DebugConfig.should_log(level) then
    return
  end
  
  -- Use existing ErrorHandler infrastructure for actual logging
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
  
  -- Route through ErrorHandler based on severity
  if level <= DebugConfig.LEVELS.ERROR then
    ErrorHandler.raise({
      key = "debug.error_level_log",
      default = prefixed_message
    }, data)
  else
    ErrorHandler.debug_log(prefixed_message, data)
  end
end

--- Enable production mode (minimal logging)
function DebugConfig.enable_production_mode()
  DebugConfig.set_level(DebugConfig.LEVELS.WARN)
  DebugConfig.log(DebugConfig.LEVELS.INFO, "Production mode enabled")
end

--- Enable development mode (verbose logging)
function DebugConfig.enable_development_mode()
  DebugConfig.set_level(DebugConfig.LEVELS.DEBUG)
  DebugConfig.log(DebugConfig.LEVELS.INFO, "Development mode enabled")
end

--- Get debug level name for display
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

--- Initialize debug system (call during mod initialization)
function DebugConfig.initialize()
  current_debug_level = detect_environment()
  DebugConfig.log(DebugConfig.LEVELS.INFO, "Debug system initialized", {
    level = current_debug_level,
    level_name = DebugConfig.get_level_name(),
    environment = current_debug_level >= DebugConfig.LEVELS.DEBUG and "development" or "production"
  })
end

return DebugConfig
