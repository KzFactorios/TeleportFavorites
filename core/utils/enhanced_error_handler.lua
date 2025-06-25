---@diagnostic disable: undefined-global
--[[
core/utils/enhanced_error_handler.lua
TeleportFavorites Factorio Mod
-----------------------------
Enhanced error handler that integrates with debug level controls.

This module wraps the existing ErrorHandler to provide debug-level-aware
logging while maintaining backward compatibility.

Usage:
  local Logger = require("core.utils.enhanced_error_handler")
  
  -- These will respect debug level settings
  Logger.trace("Detailed trace information")
  Logger.debug("Debug information") 
  Logger.info("General information")
  Logger.warn("Warning message")
  Logger.error("Error message")
  
  -- Legacy support - will route to appropriate level
  Logger.debug_log("message", data) -- Maps to debug level
]]

local DebugConfig = require("core.utils.debug_config")
local ErrorHandler = require("core.utils.error_handler")
local DevPerformanceMonitor = require("core.utils.dev_performance_monitor")

---@class EnhancedErrorHandler
local EnhancedErrorHandler = {}

--- Log a trace message (most verbose)
---@param message string Log message
---@param data table? Optional data table
function EnhancedErrorHandler.trace(message, data)
  DebugConfig.log(DebugConfig.LEVELS.TRACE, message, data)
end

--- Log a debug message
---@param message string Log message  
---@param data table? Optional data table
function EnhancedErrorHandler.debug(message, data)
  DebugConfig.log(DebugConfig.LEVELS.DEBUG, message, data)
end

--- Log an info message
---@param message string Log message
---@param data table? Optional data table
function EnhancedErrorHandler.info(message, data)
  DebugConfig.log(DebugConfig.LEVELS.INFO, message, data)
end

--- Log a warning message
---@param message string Log message
---@param data table? Optional data table
function EnhancedErrorHandler.warn(message, data)
  DebugConfig.log(DebugConfig.LEVELS.WARN, message, data)
end

--- Log an error message
---@param message string Log message
---@param data table? Optional data table
function EnhancedErrorHandler.error(message, data)
  DebugConfig.log(DebugConfig.LEVELS.ERROR, message, data)
end

--- Legacy compatibility: Map debug_log to debug level
---@param message string Log message
---@param data table? Optional data table
function EnhancedErrorHandler.debug_log(message, data)
  DebugConfig.log(DebugConfig.LEVELS.DEBUG, message, data)
end

--- Forward raise calls to original ErrorHandler (unchanged)
---@param error_spec table Error specification
---@param context table? Optional context data
function EnhancedErrorHandler.raise(error_spec, context)
  ErrorHandler.raise(error_spec, context)
end

--- Check if debug level is enabled (for performance-sensitive code)
---@param level number Debug level to check
---@return boolean enabled True if level is enabled
function EnhancedErrorHandler.is_level_enabled(level)
  return DebugConfig.should_log(level)
end

--- Conditional logging for performance-sensitive operations
---@param level number Debug level
---@param message_func function Function that returns message and data
function EnhancedErrorHandler.log_if_enabled(level, message_func)
  if DebugConfig.should_log(level) then
    local message, data = message_func()
    DebugConfig.log(level, message, data)
  end
end

--- Initialize the enhanced error handler and related systems
function EnhancedErrorHandler.initialize()
  DebugConfig.initialize()
  
  -- Initialize performance monitoring if in development mode
  if DebugConfig.get_level() >= DebugConfig.LEVELS.DEBUG then
    DevPerformanceMonitor.initialize()
  end
  
  EnhancedErrorHandler.info("Enhanced error handler initialized")
end

--- Measure performance of an operation (development only)
---@param operation_name string Name of the operation
---@param func function Function to measure
---@param context table? Optional context
---@return any result Function result
function EnhancedErrorHandler.measure_operation(operation_name, func, context)
  return DevPerformanceMonitor.measure_operation(operation_name, func, context)
end

--- Record cache operation for performance tracking
---@param operation string "hit" or "miss"
---@param cache_type string Type of cache
function EnhancedErrorHandler.record_cache_operation(operation, cache_type)
  DevPerformanceMonitor.record_cache_operation(operation, cache_type)
end

--- Take periodic memory snapshot (called from event handlers)
function EnhancedErrorHandler.take_memory_snapshot()
  DevPerformanceMonitor.take_memory_snapshot()
end

--- Get current debug configuration info
---@return table config Debug configuration info
function EnhancedErrorHandler.get_debug_info()
  local perf_summary = DevPerformanceMonitor.get_performance_summary()
  
  return {
    level = DebugConfig.get_level(),
    level_name = DebugConfig.get_level_name(),
    is_production = DebugConfig.get_level() <= DebugConfig.LEVELS.WARN,
    available_levels = DebugConfig.LEVELS,
    performance_monitoring = perf_summary
  }
end

return EnhancedErrorHandler
