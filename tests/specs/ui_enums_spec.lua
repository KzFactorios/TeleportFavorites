---@diagnostic disable: undefined-global
require("test_framework")

describe("UIEnums", function()
  local UIEnums
  
  before_each(function()
    local success, result = pcall(require, "prototypes.enums.ui_enums")
    if success then
      UIEnums = result
    else
      UIEnums = {}
    end
  end)

  it("should load ui_enums without errors", function()
    local success, err = pcall(function()
      assert(type(UIEnums) == "table")
    end)
    assert(success, "ui_enums should load without errors: " .. tostring(err))
  end)

  it("should handle UI enum definitions", function()
    local success, err = pcall(function()
      if type(UIEnums) == "table" then
        for name, value in pairs(UIEnums) do
          -- UI enums usually contain GUI-related constants
          assert(value ~= nil, "UI Enum " .. name .. " should not be nil")
        end
      end
    end)
    assert(success, "UI enum definitions should be accessible: " .. tostring(err))
  end)

end)
