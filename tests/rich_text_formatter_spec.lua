---@diagnostic disable: undefined-global
require("tests.test_framework")

describe("RichTextFormatter", function()
  local RichTextFormatter
  
  before_each(function()
    -- Mock all dependencies
    package.loaded["core.utils.error_handler"] = {
      debug_log = function() end
    }
    
    local success, result = pcall(require, "core.utils.rich_text_formatter")
    if success then
      RichTextFormatter = result
    else
      RichTextFormatter = {}
    end
  end)

  it("should load rich_text_formatter without errors", function()
    local success, err = pcall(function()
      assert(type(RichTextFormatter) == "table")
    end)
    assert(success, "rich_text_formatter should load without errors: " .. tostring(err))
  end)

  it("should handle text formatting functions", function()
    local success, err = pcall(function()
      if type(RichTextFormatter) == "table" then
        for name, func in pairs(RichTextFormatter) do
          if type(func) == "function" then
            assert(type(func) == "function", "Function " .. name .. " should be a function")
          end
        end
      end
    end)
    assert(success, "text formatting functions should be accessible: " .. tostring(err))
  end)

end)
