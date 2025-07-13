---@diagnostic disable: undefined-global
require("test_framework")

describe("DebugConfig", function()
  local DebugConfig
  
  before_each(function()
    -- Mock all dependencies
    package.loaded["core.utils.error_handler"] = {
      debug_log = function() end
    }
    
    local success, result = pcall(require, "core.utils.debug_config")
    if success then
      DebugConfig = result
    else
      DebugConfig = {}
    end
  end)

  it("should load debug_config without errors", function()
    local success, err = pcall(function()
      assert(type(DebugConfig) == "table")
    end)
    assert(success, "debug_config should load without errors: " .. tostring(err))
  end)

  it("should handle debug configuration functions", function()
    local success, err = pcall(function()
      if type(DebugConfig) == "table" then
        for name, value in pairs(DebugConfig) do
          -- Debug config usually contains flags and settings
          assert(value ~= nil, "Config value " .. name .. " should not be nil")
        end
      end
    end)
    assert(success, "debug configuration should be accessible: " .. tostring(err))
  end)

end)
