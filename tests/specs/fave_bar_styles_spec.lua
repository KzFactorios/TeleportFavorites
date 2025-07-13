---@diagnostic disable: undefined-global
require("test_framework")

describe("FaveBarStyles", function()
  
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

  it("should load fave bar styles without errors", function()
    local success, err = pcall(function()
      require("prototypes.styles.fave_bar")
    end)
    assert(success, "fave bar styles should load without errors: " .. tostring(err))
  end)

end)
