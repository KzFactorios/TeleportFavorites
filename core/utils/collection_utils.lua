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

-- ========================================
-- MATHEMATICAL UTILITIES
-- ========================================

--- Round a number to the nearest integer with proper handling of edge cases
---@param n number
---@return number rounded_number
function CollectionUtils.math_round(n)
  if type(n) ~= "number" then return 0 end
  local rounded = n >= 0 and math.floor(n + 0.5) or math.ceil(n - 0.5)
  return tostring(rounded) == "-0" and 0 or rounded
end

-- ========================================
-- TABLE UTILITIES
-- ========================================

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

--- Remove the first occurrence of a value from an array
---@param tbl table
---@param value any
---@return boolean found_and_removed
function CollectionUtils.remove_first(tbl, value)
  if type(tbl) ~= "table" then return false end
  for i, v in ipairs(tbl) do
    if v == value then
      table.remove(tbl, i)
      return true
    end
  end
  return false
end

--- Check if a table is empty
---@param tbl table
---@return boolean is_empty
function CollectionUtils.table_is_empty(tbl)
  if type(tbl) ~= "table" then return true end
  return next(tbl) == nil
end

--- Create an empty indexed array of specified size
---@param size number
---@return table empty_array
function CollectionUtils.create_empty_indexed_array(size)
  local arr = {}
  for i = 1, (size or 0) do
    arr[i] = nil
  end
  return arr
end

--- Sort array by index values
---@param tbl table
---@param sort_func function? Optional custom sort function
---@return table sorted_table
function CollectionUtils.array_sort_by_index(tbl, sort_func)
  if type(tbl) ~= "table" then return {} end
  local sorted = CollectionUtils.shallow_copy(tbl)
  table.sort(sorted, sort_func)
  return sorted
end

--- Check if an index exists in a table
---@param tbl table
---@param index any
---@return boolean index_exists
function CollectionUtils.index_is_in_table(tbl, index)
  if type(tbl) ~= "table" then return false end
  return tbl[index] ~= nil
end

--- Find element using a predicate function
---@param tbl table
---@param predicate_func function Function that takes (value, key) and returns boolean
---@return any? found_value
---@return any? found_key
function CollectionUtils.find_by_predicate(tbl, predicate_func)
  if type(tbl) ~= "table" or type(predicate_func) ~= "function" then return nil, nil end
  for k, v in pairs(tbl) do
    if predicate_func(v, k) then
      return v, k
    end
  end
  return nil, nil
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

--- Find value in table and return key
---@param tbl table
---@param value any
---@return any? found_key
function CollectionUtils.table_find(tbl, value)
  if type(tbl) ~= "table" then return nil end
  for k, v in pairs(tbl) do
    if v == value then
      return k
    end
  end
  return nil
end

--- Remove value from table
---@param tbl table
---@param value any
---@return boolean removed
function CollectionUtils.table_remove_value(tbl, value)
  if type(tbl) ~= "table" then return false end
  local key = CollectionUtils.table_find(tbl, value)
  if key ~= nil then
    tbl[key] = nil
    return true
  end
  return false
end

--- Find first match using a matcher function
---@param tbl table
---@param matcher_func function Function that takes (value, key) and returns boolean
---@return any? matched_value
---@return any? matched_key
function CollectionUtils.find_first_match(tbl, matcher_func)
  if type(tbl) ~= "table" or type(matcher_func) ~= "function" then return nil, nil end
  for k, v in pairs(tbl) do
    if matcher_func(v, k) then
      return v, k
    end
  end
  return nil, nil
end

--- Process elements until a condition is met
---@param tbl table
---@param processor_func function Function that takes (value, key) and returns boolean to continue
---@return boolean condition_met
function CollectionUtils.process_until_match(tbl, processor_func)
  if type(tbl) ~= "table" or type(processor_func) ~= "function" then return false end
  for k, v in pairs(tbl) do
    if processor_func(v, k) then return true end
  end
  return false
end

-- ========================================
-- FUNCTIONAL PROGRAMMING UTILITIES
-- ========================================

--- Map function: transform each element in a table using a mapper function
---@param tbl table
---@param mapper_func function Function that takes (value, key) and returns transformed value
---@return table transformed_table
function CollectionUtils.map(tbl, mapper_func)
  if type(tbl) ~= "table" or type(mapper_func) ~= "function" then return {} end
  local result = {}
  for k, v in pairs(tbl) do
    result[k] = mapper_func(v, k)
  end
  return result
end

--- Filter function: select elements that match a predicate
---@param tbl table
---@param predicate_func function Function that takes (value, key) and returns boolean
---@return table filtered_table
function CollectionUtils.filter(tbl, predicate_func)
  if type(tbl) ~= "table" or type(predicate_func) ~= "function" then return {} end
  local result = {}
  for k, v in pairs(tbl) do
    if predicate_func(v, k) then
      result[k] = v
    end
  end
  return result
end

--- Reduce function: accumulate values using a reducer function
---@param tbl table
---@param reducer_func function Function that takes (accumulator, value, key) and returns new accumulator
---@param initial_value any Initial accumulator value
---@return any accumulated_result
function CollectionUtils.reduce(tbl, reducer_func, initial_value)
  if type(tbl) ~= "table" or type(reducer_func) ~= "function" then return initial_value end
  local accumulator = initial_value
  for k, v in pairs(tbl) do
    accumulator = reducer_func(accumulator, v, k)
  end
  return accumulator
end

--- ForEach function: execute a function for each element
---@param tbl table
---@param action_func function Function that takes (value, key)
function CollectionUtils.for_each(tbl, action_func)
  if type(tbl) ~= "table" or type(action_func) ~= "function" then return end
  for k, v in pairs(tbl) do
    action_func(v, k)
  end
end

--- Partition function: split a table into two based on a predicate
---@param tbl table
---@param predicate_func function Function that takes (value, key) and returns boolean
---@return table true_partition
---@return table false_partition
function CollectionUtils.partition(tbl, predicate_func)
  if type(tbl) ~= "table" or type(predicate_func) ~= "function" then return {}, {} end
  local true_part, false_part = {}, {}
  for k, v in pairs(tbl) do
    if predicate_func(v, k) then
      true_part[k] = v
    else
      false_part[k] = v
    end
  end
  return true_part, false_part
end

return CollectionUtils
