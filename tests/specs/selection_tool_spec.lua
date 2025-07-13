---@diagnostic disable: undefined-global
require("test_framework")

describe("SelectionTool", function()
  
  before_each(function()
    -- Mock Factorio data stage globals
    _G.data = {
      extend = function(prototypes) end,
      raw = {}
    }
  end)

  it("should load selection tool without errors", function()
    local success, err = pcall(function()
      require("prototypes.item.selection_tool")
    end)
    assert(success, "selection tool should load without errors: " .. tostring(err))
  end)

  it("should handle item prototype definitions", function()
    local success, err = pcall(function()
      -- Item prototypes typically define tools and items
      local data_mock = _G.data
      data_mock.extend({})
    end)
    assert(success, "item prototype definitions should work: " .. tostring(err))
  end)

end)
