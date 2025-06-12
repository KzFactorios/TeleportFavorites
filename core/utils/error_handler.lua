---@diagnostic disable: undefined-global
--[[
core/utils/error_handler.lua
TeleportFavorites Factorio Mod
-----------------------------
Rudimentary error handling module for bubbling errors up through function calls.
Provides consistent error reporting and logging patterns.
]]

local Constants = require("constants")

---@class ErrorResult
---@field success boolean
---@field error_type string?
---@field message string?
---@field context table?

local ErrorHandler = {}

--- Error types for consistent categorization
ErrorHandler.ERROR_TYPES = {
  VALIDATION_FAILED = "validation_failed",
  POSITION_INVALID = "position_invalid", 
  CHART_TAG_FAILED = "chart_tag_failed",
  GPS_PARSE_FAILED = "gps_parse_failed",
  MISSING_DEPENDENCY = "missing_dependency",
  FACTORIO_API_ERROR = "factorio_api_error"
}

--- Create a success result
---@param data any Optional data to include
---@return ErrorResult
function ErrorHandler.success(data)
  return {
    success = true,
    data = data
  }
end

--- Create an error result
---@param error_type string Error type from ERROR_TYPES
---@param message string Human readable error message
---@param context table? Additional context for debugging
---@return ErrorResult
function ErrorHandler.error(error_type, message, context)
  return {
    success = false,
    error_type = error_type,
    message = message,
    context = context or {}
  }
end

--- Check if result is an error and handle it
---@param result ErrorResult
---@param player LuaPlayer? Player to show message to
---@param should_print boolean? Whether to print to player (default true)
---@return boolean is_error
function ErrorHandler.handle_error(result, player, should_print)
  if result.success then
    return false
  end
  
  should_print = should_print ~= false -- default to true
  
  -- Log error for debugging
  if result.context then
    log("[TeleportFavorites] Error: " .. result.error_type .. " - " .. result.message .. 
        " Context: " .. serpent.line(result.context))
  else
    log("[TeleportFavorites] Error: " .. result.error_type .. " - " .. result.message)
  end
  
  -- Show message to player if requested
  if should_print and player and player.valid then
    player.print("[TeleportFavorites] " .. result.message)
  end
  
  return true
end

--- Debug logging helper
---@param message string
---@param context table?
function ErrorHandler.debug_log(message, context)
  if context then
    log("[TeleportFavorites] DEBUG: " .. message .. " - " .. serpent.line(context))
  else
    log("[TeleportFavorites] DEBUG: " .. message)
  end
end

--- Warning logging helper  
---@param message string
---@param context table?
function ErrorHandler.warn_log(message, context)
  if context then
    log("[TeleportFavorites] WARNING: " .. message .. " - " .. serpent.line(context))
  else
    log("[TeleportFavorites] WARNING: " .. message)
  end
end

return ErrorHandler
