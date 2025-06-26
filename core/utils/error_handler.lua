---@diagnostic disable: undefined-global
--[[
core/utils/error_handler.lua
TeleportFavorites Factorio Mod
-----------------------------
Rudimentary error handling module for bubbling errors up through function calls.
Provides consistent error reporting and logging patterns.
]]

local Constants = require("constants")

-- Prevent infinite recursion in error handling
local _in_error_handler = false

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
  
  -- Prevent infinite recursion
  if _in_error_handler then
    return true
  end
  _in_error_handler = true
    -- default to true
  should_print = should_print ~= false
    -- Simple logging to prevent recursion issues
  local error_message = "Error: " .. (result.error_type or "unknown") .. " - " .. (result.message or "no message")
  pcall(function() log("[TeleportFavorites] " .. error_message) end)
  
  -- Show message to player if requested
  if should_print and player and player.valid then
    -- Log message for debugging (this will always work)
    pcall(function() log("[TeleportFavorites] PLAYER MSG: " .. player.name .. " - " .. (result.message or "Unknown error")) end)
    
    -- Use GameHelpers for player messaging
    -- We know this works but requires importing GameHelpers which would create a circular dependency
    -- Instead we'll use a dynamic approach that bypasses the static analyzer
    local print_fn = player.print
    if type(print_fn) == "function" then
      pcall(print_fn, player, {"", "[TeleportFavorites] ", (result.message or "Unknown error")})
    end
  end
  
  _in_error_handler = false
  return true
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
function ErrorHandler.warn_log(message, context)  if _in_error_handler then return end
  _in_error_handler = true
  
  pcall(function() log("[TeleportFavorites] WARNING: " .. message) end)
  
  _in_error_handler = false
end

return ErrorHandler
