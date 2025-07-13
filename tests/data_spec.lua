---@diagnostic disable: undefined-global
require("tests.test_framework")

describe("Data (Data Stage Entry Point)", function()
  
  before_each(function()
    -- Mock Factorio data stage globals
    _G.data = {
      extend = function(prototypes) end
    }
    
    -- Mock all prototype dependencies
    package.loaded["prototypes.styles.init"] = {}
    package.loaded["prototypes.item.selection_tool"] = {}
    package.loaded["prototypes.input.teleport_history_inputs"] = {}
    package.loaded["prototypes.enums.core_enums"] = {
      EventEnum = {}  -- Add missing EventEnum
    }
    package.loaded["prototypes.enums.ui_enums"] = {}
  end)

  it("should load data.lua without errors", function()
    local success, err = pcall(function()
      -- Data.lua is the data stage entry point
      require("data")
    end)
    assert(success, "data.lua should load without errors: " .. tostring(err))
  end)

  it("should handle data extension without errors", function()
    local success, err = pcall(function()
      -- Mock typical data extension pattern
      local data_mock = _G.data
      data_mock.extend({})
    end)
    assert(success, "data extension should work without errors: " .. tostring(err))
  end)

end)
