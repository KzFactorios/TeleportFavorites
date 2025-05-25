-- tests/unit/test_helpers.lua
-- Unit tests for core.utils.Helpers
local Helpers = require("core.utils.Helpers")

local function test_trim()
  assert(Helpers.trim("  foo  ") == "foo", "Trim should remove leading/trailing spaces")
  assert(Helpers.trim("\tbar\n") == "bar", "Trim should remove tabs/newlines")
  assert(Helpers.trim("") == "", "Trim of empty string is empty")
end

local function test_pad()
  assert(Helpers.pad(5, 3) == "005", "Pad should add leading zeros")
  assert(Helpers.pad(123, 2) == "123", "Pad should not truncate")
end

local function run_all()
  test_trim()
  test_pad()
  print("All Helpers tests passed.")
end

run_all()
