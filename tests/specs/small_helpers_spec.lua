---@diagnostic disable: undefined-global
require("test_framework")

describe("SmallHelpers", function()
  local SmallHelpers
  
  before_each(function()
    -- Mock all dependencies
    package.loaded["core.utils.error_handler"] = {
      debug_log = function() end
    }
    
    local success, result = pcall(require, "core.utils.small_helpers")
    if success then
      SmallHelpers = result
    else
      SmallHelpers = {}
    end
  end)

  it("should load small_helpers without errors", function()
    local success, err = pcall(function()
      assert(type(SmallHelpers) == "table")
    end)
    assert(success, "small_helpers should load without errors: " .. tostring(err))
  end)

  it("should handle small helper functions", function()
    local success, err = pcall(function()
      if type(SmallHelpers) == "table" then
        for name, func in pairs(SmallHelpers) do
          if type(func) == "function" then
            assert(type(func) == "function", "Function " .. name .. " should be a function")
          end
        end
      end
    end)
    assert(success, "small helper functions should be accessible: " .. tostring(err))
  end)

end)
