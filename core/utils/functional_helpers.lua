--[[
functional_helpers.lua
TeleportFavorites Factorio Mod
-----------------------------
Functional programming utilities: map, filter, reduce, forEach, partition, etc.
Extracted from helpers_suite.lua for better organization and maintainability.
]]

---@class FunctionalHelpers
local FunctionalHelpers = {}

--- Map function: transform each element in a table using a mapper function
--- @param tbl table
--- @param mapper_func function Function that takes (value, key) and returns transformed value
--- @return table New table with transformed values
function FunctionalHelpers.map(tbl, mapper_func)
  if type(tbl) ~= "table" or type(mapper_func) ~= "function" then return {} end
  local result = {}
  for k, v in pairs(tbl) do
    result[k] = mapper_func(v, k)
  end
  return result
end

--- Filter function: select elements that match a predicate
--- @param tbl table
--- @param predicate_func function Function that takes (value, key) and returns boolean
--- @return table New table with filtered values
function FunctionalHelpers.filter(tbl, predicate_func)
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
--- @param tbl table
--- @param reducer_func function Function that takes (accumulator, value, key) and returns new accumulator
--- @param initial_value any Initial value for the accumulator
--- @return any Final accumulated value
function FunctionalHelpers.reduce(tbl, reducer_func, initial_value)
  if type(tbl) ~= "table" or type(reducer_func) ~= "function" then return initial_value end
  local accumulator = initial_value
  for k, v in pairs(tbl) do
    accumulator = reducer_func(accumulator, v, k)
  end
  return accumulator
end

--- ForEach function: execute a function for each element without returning anything
--- @param tbl table
--- @param action_func function Function that takes (value, key)
function FunctionalHelpers.for_each(tbl, action_func)
  if type(tbl) ~= "table" or type(action_func) ~= "function" then return end
  for k, v in pairs(tbl) do
    action_func(v, k)
  end
end

--- Partition function: split table into two based on predicate
--- @param tbl table
--- @param predicate_func function Function that takes (value, key) and returns boolean
--- @return table, table Two tables: {matching}, {not_matching}
function FunctionalHelpers.partition(tbl, predicate_func)
  if type(tbl) ~= "table" or type(predicate_func) ~= "function" then
    return {}, {}
  end
  local matching, not_matching = {}, {}
  for k, v in pairs(tbl) do
    if predicate_func(v, k) then
      matching[k] = v
    else
      not_matching[k] = v
    end
  end
  return matching, not_matching
end

return FunctionalHelpers
