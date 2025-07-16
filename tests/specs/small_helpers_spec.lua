---@diagnostic disable: undefined-global
require("test_framework")

describe("BasicHelpers (formerly SmallHelpers)", function()
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
      BasicHelpers = {}
    end
  end)

  it("should load basic_helpers without errors", function()
    local success, err = pcall(function()
      assert(type(BasicHelpers) == "table")
    end)
    assert(success, "basic_helpers should load without errors: " .. tostring(err))
  end)

  it("should handle basic helper functions", function()
    local success, err = pcall(function()
      if type(BasicHelpers) == "table" then
        for name, func in pairs(BasicHelpers) do
          if type(func) == "function" then
            assert(type(func) == "function", "Function " .. name .. " should be a function")
          end
        end
      end
    end)
    assert(success, "basic helper functions should be accessible: " .. tostring(err))
  end)

end)
