-- tests/unit/test_helpers.lua
-- Unit tests for core.utils.Helpers
local Helpers = require("core.utils.helpers")

local function test_trim()
  assert(Helpers.trim("  foo  ") == "foo", "Trim should remove leading/trailing spaces")
  assert(Helpers.trim("\tbar\n") == "bar", "Trim should remove tabs/newlines")
  assert(Helpers.trim("") == "", "Trim of empty string is empty")
end

local function test_pad()
  assert(Helpers.pad(5, 3) == "005", "Pad should add leading zeros")
  assert(Helpers.pad(123, 2) == "123", "Pad should not truncate")
end

local function test_table_count()
  -- Dense array
  local arr = {1,2,3}
  assert(Helpers.table_count(arr) == 3, "Dense array should count as 3")
  -- Sparse array
  local sparse = { [1]=1, [3]=3, [10]=10 }
  assert(Helpers.table_count(sparse) == 3, "Sparse array should count all entries")
  -- Empty table
  local empty = {}
  assert(Helpers.table_count(empty) == 0, "Empty table should count as 0")
  -- Non-table
  ---@diagnostic disable-next-line: param-type-mismatch
  assert(Helpers.table_count(nil) == 0, "Nil should count as 0")
  ---@diagnostic disable-next-line: param-type-mismatch
  assert(Helpers.table_count(123) == 0, "Non-table value should count as 0")
end

local function run_all()
  test_trim()
  test_pad()
  test_table_count()
  print("All Helpers tests passed.")
end

run_all()
