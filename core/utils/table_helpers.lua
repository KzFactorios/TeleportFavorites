--[[
table_helpers.lua
TeleportFavorites Factorio Mod
-----------------------------
Table manipulation utilities: deep/shallow copy, equality, searching, removal, counting, etc.
Extracted from helpers_suite.lua for better organization and maintainability.
]]

---@class TableHelpers
local TableHelpers = {}

function TableHelpers.tables_equal(a, b)
  if a == b then return true end
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  for k, v in pairs(a) do
    if type(v) == "table" and type(b[k]) == "table" then
      if not TableHelpers.tables_equal(v, b[k]) then return false end
    elseif v ~= b[k] then
      return false
    end
  end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end

function TableHelpers.deep_copy(orig)
  if type(orig) ~= 'table' then return orig end
  local copy = {}
  for k, v in pairs(orig) do
    copy[k] = type(v) == 'table' and TableHelpers.deep_copy(v) or v
  end
  return copy
end

function TableHelpers.shallow_copy(tbl)
  local t = {}
  for k, v in pairs(tbl) do t[k] = v end
  return t
end

function TableHelpers.remove_first(tbl, value)
  if type(tbl) ~= "table" then return false end
  for i, v in ipairs(tbl) do
    if v == value then
      table.remove(tbl, i); return true
    end
  end
  return false
end

function TableHelpers.table_is_empty(tbl)
  return type(tbl) ~= "table" or next(tbl) == nil
end

function TableHelpers.create_empty_indexed_array(count)
  local arr = {}
  for i = 1, count do arr[i] = {} end
  return arr
end

function TableHelpers.array_sort_by_index(array)
  local arr = {}
  for i, item in ipairs(array) do
    if type(item) == "table" then
      item.slot_num = i; arr[#arr + 1] = item
    end
  end
  return arr
end

function TableHelpers.index_is_in_table(_table, idx)
  if type(_table) == "table" then
    for x, v in pairs(_table) do if v == idx then return true, x end end
  end
  return false, -1
end

--- Returns the value and the index of the first element in the table that matches the predicate function.
--- If no match is found, returns nil, nil.
---@param _table table: The table to search
---@param predicate function: A function that takes two arguments (value, key) and returns true if it matches
---@return any, number: The value and key_index of the first matching element, or nil if not found
function TableHelpers.find_by_predicate(_table, predicate)
  if type(_table) ~= "table" or type(predicate) ~= "function" then return nil, 0 end
  for k, v in pairs(_table) do if predicate(v, k) then return v, k end end
  return nil, 0
end

function TableHelpers.table_count(t)
  local n = 0
  if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end
  return n
end

function TableHelpers.table_find(tbl, value)
  if type(tbl) ~= "table" then return nil end
  local function value_matcher(v, k)
    return v == value and k or nil
  end
  return TableHelpers.find_first_match(tbl, value_matcher)
end

function TableHelpers.table_remove_value(tbl, value)
  if type(tbl) ~= "table" then return false end
  local function remove_matching_value(v, k)
    if v == value then
      if type(k) == "number" then
        table.remove(tbl, k)
      else
        tbl[k] = nil
      end
      return true
    end
    return false
  end
  return TableHelpers.process_until_match(tbl, remove_matching_value)
end

--- Generic helper: Find first match using a matcher function
--- @param tbl table
--- @param matcher_func function Function that takes (value, key) and returns result or nil
--- @return any
function TableHelpers.find_first_match(tbl, matcher_func)
  if type(tbl) ~= "table" or type(matcher_func) ~= "function" then return nil end
  for k, v in pairs(tbl) do
    local result = matcher_func(v, k)
    if result ~= nil then return result end
  end
  return nil
end

--- Generic helper: Process table until a condition is met
--- @param tbl table
--- @param processor_func function Function that takes (value, key) and returns true to stop processing
--- @return boolean True if condition was met
function TableHelpers.process_until_match(tbl, processor_func)
  if type(tbl) ~= "table" or type(processor_func) ~= "function" then return false end
  for k, v in pairs(tbl) do
    if processor_func(v, k) then return true end
  end
  return false
end

return TableHelpers
