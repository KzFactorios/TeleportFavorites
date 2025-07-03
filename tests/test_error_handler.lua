local ErrorHandler = require("core.utils.error_handler")

describe("ErrorHandler", function()
  it("should handle errors gracefully", function()
    local ok, err = pcall(function() ErrorHandler.raise("Test error") end)
    assert.is_false(ok)
    assert.is_string(err)
  end)
end)
