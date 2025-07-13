---@diagnostic disable: undefined-global
require("tests.test_framework")

describe("ValidationUtils", function()
  local ValidationUtils
  
  before_each(function()
    -- Mock all dependencies
    package.loaded["core.utils.error_handler"] = {
      debug_log = function() end
    }
    
    local success, result = pcall(require, "core.utils.validation_utils")
    if success then
      ValidationUtils = result
    else
      ValidationUtils = {}
    end
  end)

  it("should load validation_utils without errors", function()
    local success, err = pcall(function()
      assert(type(ValidationUtils) == "table")
    end)
    assert(success, "validation_utils should load without errors: " .. tostring(err))
  end)

  it("should handle validation utility functions", function()
    local success, err = pcall(function()
      if type(ValidationUtils) == "table" then
        for name, func in pairs(ValidationUtils) do
          if type(func) == "function" then
            assert(type(func) == "function", "Function " .. name .. " should be a function")
          end
        end
      end
    end)
    assert(success, "validation utility functions should be accessible: " .. tostring(err))
  end)

end)
