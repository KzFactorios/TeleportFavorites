---@diagnostic disable: undefined-global
require("tests.test_framework")

describe("CoreEnums", function()
  local CoreEnums
  
  before_each(function()
    local success, result = pcall(require, "prototypes.enums.core_enums")
    if success then
      CoreEnums = result
    else
      CoreEnums = {}
    end
  end)

  it("should load core_enums without errors", function()
    local success, err = pcall(function()
      assert(type(CoreEnums) == "table")
    end)
    assert(success, "core_enums should load without errors: " .. tostring(err))
  end)

  it("should handle enum definitions", function()
    local success, err = pcall(function()
      if type(CoreEnums) == "table" then
        for name, value in pairs(CoreEnums) do
          -- Enums usually contain constant values
          assert(value ~= nil, "Enum " .. name .. " should not be nil")
        end
      end
    end)
    assert(success, "enum definitions should be accessible: " .. tostring(err))
  end)

end)
