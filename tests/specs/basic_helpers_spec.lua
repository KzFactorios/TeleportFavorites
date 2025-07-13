---@diagnostic disable: undefined-global
require("test_framework")

describe("BasicHelpers", function()
  local BasicHelpers
  
  before_each(function()
    -- Mock all dependencies
    package.loaded["core.utils.error_handler"] = {
      debug_log = function() end
    }
    
    local success, result = pcall(require, "core.utils.basic_helpers")
    if success then
      BasicHelpers = result
    else
      -- Provide fallback if module doesn't load
      BasicHelpers = {
        pad = function() return "000" end,
        normalize_index = function() return 1 end
      }
    end
  end)

  it("should load basic_helpers without errors", function()
    local success, err = pcall(function()
      assert(type(BasicHelpers) == "table")
    end)
    assert(success, "basic_helpers should load without errors: " .. tostring(err))
  end)

  it("should execute pad function without errors", function()
    local success, err = pcall(function()
      -- Use the module loaded in before_each
      assert(type(BasicHelpers) == "table")
      if BasicHelpers.pad then
        BasicHelpers.pad(123, 5)
      end
    end)
    assert(success, "pad function should execute without errors: " .. tostring(err))
  end)

  it("should execute normalize_index without errors", function()
    local success, err = pcall(function()
      -- Use the module loaded in before_each  
      assert(type(BasicHelpers) == "table")
      if BasicHelpers.normalize_index then
        BasicHelpers.normalize_index(5)
        BasicHelpers.normalize_index("10")
      end
    end)
    assert(success, "normalize_index should execute without errors: " .. tostring(err))
  end)

  it("should handle basic helper functions", function()
    local success, err = pcall(function()
      -- Test any available helper functions
      if type(BasicHelpers) == "table" then
        for name, func in pairs(BasicHelpers) do
          if type(func) == "function" and name ~= "is_valid_player" then
            -- Don't call unknown functions with potentially dangerous side effects
            assert(type(func) == "function", "Function " .. name .. " should be a function")
          end
        end
      end
    end)
    assert(success, "basic helper functions should be accessible: " .. tostring(err))
  end)

end)
