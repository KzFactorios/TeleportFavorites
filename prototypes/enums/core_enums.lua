--[[
Core Enums - TeleportFavorites
=============================
Consolidated core system enumerations including events, return states, and enum utilities.

This module consolidates:
- event_enum.lua - Custom event name definitions
- return_state_enum.lua - Function return state constants
- enum.lua - Main enum utility functions

Provides a unified API for all core system constants and enum manipulation functions.
]]

---@class CoreEnums
local CoreEnums = {}

-- ========================================
-- EVENT ENUMERATIONS
-- ========================================

--- Custom event names used throughout the mod
CoreEnums.Events = {
  ADD_TAG_INPUT = "add-tag-input",
  TELEPORT_TO_FAVORITE = "teleport_to_favorite-",
  ON_OPEN_TAG_EDITOR = "on_open_tag_editor",
  CACHE_DUMP = "cache_dump"
}

-- ========================================
-- RETURN STATE ENUMERATIONS
-- ========================================

--- Standard return states for functions throughout the mod
CoreEnums.ReturnStates = {
  SUCCESS = "success",
  FAILURE = "failure"
}

-- ========================================
-- ENUM UTILITY FUNCTIONS
-- ========================================

--- Given a value to match and an enum table, return the key for the matching value (or nil if not found)
--- @param value any The value to find
--- @param enum table The enum table to search
--- @return string|nil The key name for the matching value
function CoreEnums.get_enum_by_value(value, enum)
  if type(enum) ~= "table" then return nil end
  for k, v in pairs(enum) do
    if v == value then
      return k
    end
  end
  return nil
end

--- Check if a value exists in an enum table
--- @param value any The value to check
--- @param enum table The enum table to check against
--- @return boolean True if value exists in enum
function CoreEnums.is_value_member_enum(value, enum)
  if not value then return false end
  if type(enum) ~= "table" then return false end
  for _, v in pairs(enum) do
    if v == value then
      return true
    end
  end
  return false
end

--- Return a list of key names for an enum table
--- @param enum table The enum table
--- @return string[] Array of key names
function CoreEnums.get_key_names(enum)
  if type(enum) ~= "table" then return {} end
  local function extract_key(_, key)
    return key
  end
  return CoreEnums.map_enum(enum, extract_key)
end

--- Return a list of values for an enum table
--- @param enum table The enum table
--- @return any[] Array of values
function CoreEnums.get_key_values(enum)
  if type(enum) ~= "table" then return {} end
  local function extract_value(value, _)
    return value
  end
  return CoreEnums.map_enum(enum, extract_value)
end

--- Map over enum entries with a transform function
--- @param enum table The enum table to map over
--- @param transform_func function Function that takes (value, key) and returns transformed result
--- @return table Array of transformed results
function CoreEnums.map_enum(enum, transform_func)
  if type(enum) ~= "table" or type(transform_func) ~= "function" then return {} end
  local result = {}
  for k, v in pairs(enum) do
    table.insert(result, transform_func(v, k))
  end
  return result
end

-- ========================================
-- BACKWARD COMPATIBILITY ALIASES
-- ========================================

-- Maintain backward compatibility with old structure
CoreEnums.EventEnum = CoreEnums.Events
CoreEnums.ReturnStateEnum = CoreEnums.ReturnStates

return CoreEnums
