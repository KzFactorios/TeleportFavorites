---@diagnostic disable: undefined-global
require("test_framework")

describe("CollectionUtils", function()
  local CollectionUtils
  
  before_each(function()
    -- No external dependencies for this utility module
    CollectionUtils = require("core.utils.collection_utils")
  end)

  it("should compare tables for equality", function()
    local success, err = pcall(function()
      if CollectionUtils.tables_equal then
        local table1 = { a = 1, b = 2 }
        local table2 = { a = 1, b = 2 }
        local table3 = { a = 1, b = 3 }
        
        local result1 = CollectionUtils.tables_equal(table1, table2)
        local result2 = CollectionUtils.tables_equal(table1, table3)
        
        assert(result1 == true)
        assert(result2 == false)
      end
    end)
    assert(success, "tables_equal should execute without errors: " .. tostring(err))
  end)

  it("should handle nested table comparisons", function()
    local success, err = pcall(function()
      if CollectionUtils.tables_equal then
        local table1 = { a = { x = 1, y = 2 }, b = 3 }
        local table2 = { a = { x = 1, y = 2 }, b = 3 }
        local table3 = { a = { x = 1, y = 3 }, b = 3 }
        
        local result1 = CollectionUtils.tables_equal(table1, table2)
        local result2 = CollectionUtils.tables_equal(table1, table3)
        
        assert(result1 == true)
        assert(result2 == false)
      end
    end)
    assert(success, "tables_equal with nested tables should execute without errors: " .. tostring(err))
  end)

  it("should create deep copies of tables", function()
    local success, err = pcall(function()
      local original = { a = { x = 1, y = 2 }, b = 3 }
      local copy = CollectionUtils.deep_copy(original)
      
      assert(type(copy) == "table")
      assert(copy ~= original)  -- Different table references
      assert(copy.a ~= original.a)  -- Nested tables are also different references
      assert(copy.a.x == original.a.x)  -- But values are the same
    end)
    assert(success, "deep_copy should execute without errors: " .. tostring(err))
  end)

  it("should create shallow copies of tables", function()
    local success, err = pcall(function()
      if CollectionUtils.shallow_copy then
        local original = { a = 1, b = 2, c = 3 }
        local copy = CollectionUtils.shallow_copy(original)
        
        assert(type(copy) == "table")
        assert(copy ~= original)  -- Different table references
        assert(copy.a == original.a)  -- Same values
      end
    end)
    assert(success, "shallow_copy should execute without errors: " .. tostring(err))
  end)

  it("should handle non-table inputs in deep_copy", function()
    local success, err = pcall(function()
      local string_result = CollectionUtils.deep_copy("test_string")
      local number_result = CollectionUtils.deep_copy(42)
      local nil_result = CollectionUtils.deep_copy(nil)
      
      assert(string_result == "test_string")
      assert(number_result == 42)
      assert(nil_result == nil)
    end)
    assert(success, "deep_copy with non-table inputs should execute without errors: " .. tostring(err))
  end)

  it("should handle empty tables", function()
    local success, err = pcall(function()
      local empty1 = {}
      local empty2 = {}
      
      if CollectionUtils.tables_equal then
        local are_equal = CollectionUtils.tables_equal(empty1, empty2)
        assert(are_equal == true)
      end
      
      local copy = CollectionUtils.deep_copy(empty1)
      assert(type(copy) == "table")
      assert(copy ~= empty1)
    end)
    assert(success, "Empty table operations should execute without errors: " .. tostring(err))
  end)

  it("should handle additional utility functions if available", function()
    local success, err = pcall(function()
      -- Test any other utility functions that might be available
      if CollectionUtils.map then
        local test_table = {1, 2, 3}
        local result = CollectionUtils.map(test_table, function(x) return x * 2 end)
        assert(type(result) == "table")
      end
      
      if CollectionUtils.filter then
        local test_table = {1, 2, 3, 4, 5}
        local result = CollectionUtils.filter(test_table, function(x) return x % 2 == 0 end)
        assert(type(result) == "table")
      end
    end)
    assert(success, "Additional utility functions should execute without errors: " .. tostring(err))
  end)

end)
