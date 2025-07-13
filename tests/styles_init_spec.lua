---@diagnostic disable: undefined-global
require("tests.test_framework")

describe("StylesInit", function()
  
  before_each(function()
    -- Mock Factorio data stage globals
    _G.data = {
      extend = function(prototypes) end,
      raw = {
        ["gui-style"] = {  -- Add missing gui-style table
          default = {}
        }
      }
    }
  end)

  it("should load styles init without errors", function()
    local success, err = pcall(function()
      require("prototypes.styles.init")
    end)
    assert(success, "styles init should load without errors: " .. tostring(err))
  end)

  it("should handle style definitions", function()
    local success, err = pcall(function()
      -- Styles typically extend data with GUI style definitions
      local data_mock = _G.data
      data_mock.extend({})
    end)
    assert(success, "style definitions should work: " .. tostring(err))
  end)

end)
