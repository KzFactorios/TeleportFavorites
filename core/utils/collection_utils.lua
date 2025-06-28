---@diagnostic disable: undefined-global
--[[
core/utils/collection_utils.lua
TeleportFavorites Factorio Mod
-----------------------------
Consolidated collection and data manipulation utilities.

This module consolidates:
- table_helpers.lua - Table manipulation utilities
- functional_helpers.lua - Functional programming utilities
- math_helpers.lua - Mathematical operations

Provides a unified API for all data structure operations throughout the mod.
]]

---@class CollectionUtils
local CollectionUtils = {}

--- Deep comparison of two tables
---@param a table
---@param b table
---@return boolean are_equal
function CollectionUtils.tables_equal(a, b)
  if a == b then return true end
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  for k, v in pairs(a) do
    if type(v) == "table" and type(b[k]) == "table" then
      if not CollectionUtils.tables_equal(v, b[k]) then return false end
    elseif v ~= b[k] then
      return false
    end
  end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end

--- Create a deep copy of a table
---@param orig table
---@return table copied_table
function CollectionUtils.deep_copy(orig)
  if type(orig) ~= 'table' then return orig end
  local copy = {}
  for k, v in pairs(orig) do
    copy[k] = (type(v) == 'table') and CollectionUtils.deep_copy(v) or v
  end
  return copy
end

--- Create a shallow copy of a table
---@param orig table
---@return table copied_table
function CollectionUtils.shallow_copy(orig)
  if type(orig) ~= 'table' then return orig end
  local copy = {}
  for k, v in pairs(orig) do
    copy[k] = v
  end
  return copy
end

--- Count elements in a table
---@param tbl table
---@return number count
function CollectionUtils.table_count(tbl)
  if type(tbl) ~= "table" then return 0 end
  local count = 0
  for _ in pairs(tbl) do
    count = count + 1
  end
  return count
end

return CollectionUtils
