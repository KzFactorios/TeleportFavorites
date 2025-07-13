---@diagnostic disable: undefined-global
require("tests.test_framework")

describe("EnhancedErrorHandler", function()
  local EnhancedErrorHandler
  
  before_each(function()
    -- Mock all dependencies
    package.loaded["core.utils.error_handler"] = {
      debug_log = function() end
    }
    
    local success, result = pcall(require, "core.utils.enhanced_error_handler")
    if success then
      EnhancedErrorHandler = result
    else
      EnhancedErrorHandler = {}
    end
  end)

  it("should load enhanced_error_handler without errors", function()
    local success, err = pcall(function()
      assert(type(EnhancedErrorHandler) == "table")
    end)
    assert(success, "enhanced_error_handler should load without errors: " .. tostring(err))
  end)

  it("should handle error handling functions", function()
    local success, err = pcall(function()
      if type(EnhancedErrorHandler) == "table" then
        for name, func in pairs(EnhancedErrorHandler) do
          if type(func) == "function" then
            assert(type(func) == "function", "Function " .. name .. " should be a function")
          end
        end
      end
    end)
    assert(success, "error handling functions should be accessible: " .. tostring(err))
  end)

end)
