local ErrorHandler = require("core.utils.error_handler")
local mock_player_data = require("tests.mocks.mock_player_data")

describe("ErrorHandler", function()
  it("should handle errors gracefully", function()
    -- Setup mock data for extensibility
    local _ = mock_player_data.create_mock_player_data()
    local ok, err = pcall(function() ErrorHandler.raise("Test error") end)
    assert.is_false(ok)
    assert.is_string(err)
  end)
end)
