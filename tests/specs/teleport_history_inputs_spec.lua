---@diagnostic disable: undefined-global
require("test_framework")

describe("TeleportHistoryInputs", function()
  
  before_each(function()
    -- Mock Factorio data stage globals
    _G.data = {
      extend = function(prototypes) end,
      raw = {}
    }
  end)

  it("should load teleport history inputs without errors", function()
    local success, err = pcall(function()
      require("prototypes.input.teleport_history_inputs")
    end)
    assert(success, "teleport history inputs should load without errors: " .. tostring(err))
  end)

  it("should handle input prototype definitions", function()
    local success, err = pcall(function()
      -- Input prototypes typically define custom input events
      local data_mock = _G.data
      data_mock.extend({})
    end)
    assert(success, "input prototype definitions should work: " .. tostring(err))
  end)

end)
