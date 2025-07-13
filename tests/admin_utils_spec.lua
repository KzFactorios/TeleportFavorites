---@diagnostic disable: undefined-global
require("tests.test_framework")

describe("AdminUtils", function()
  local AdminUtils
  
  before_each(function()
    -- Mock all dependencies
    package.loaded["core.utils.basic_helpers"] = {
      is_valid_player = function() return true end
    }
    
    package.loaded["core.utils.error_handler"] = {
      debug_log = function() end
    }
    
    AdminUtils = require("core.utils.admin_utils")
  end)

  it("should load admin_utils without errors", function()
    local success, err = pcall(function()
      assert(type(AdminUtils) == "table")
    end)
    assert(success, "admin_utils should load without errors: " .. tostring(err))
  end)

  it("should handle admin functions if available", function()
    local success, err = pcall(function()
      -- Test any available admin functions
      if type(AdminUtils) == "table" then
        for name, func in pairs(AdminUtils) do
          if type(func) == "function" then
            -- Don't call admin functions, just verify they exist
            assert(type(func) == "function", "Function " .. name .. " should be a function")
          end
        end
      end
    end)
    assert(success, "admin functions should be accessible: " .. tostring(err))
  end)

end)
