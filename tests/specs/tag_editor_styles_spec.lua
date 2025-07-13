---@diagnostic disable: undefined-global
require("test_framework")

describe("TagEditorStyles", function()
  
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

  it("should load tag editor styles without errors", function()
    local success, err = pcall(function()
      require("prototypes.styles.tag_editor")
    end)
    assert(success, "tag editor styles should load without errors: " .. tostring(err))
  end)

end)
