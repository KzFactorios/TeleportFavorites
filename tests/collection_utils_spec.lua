local CollectionUtils = require("core.utils.collection_utils")
local mock_player_data = require("tests.mocks.mock_player_data")

describe("CollectionUtils", function()
  it("should filter a table correctly", function()
    local _ = mock_player_data.create_mock_player_data()
    local t = {1, 2, 3, 4}
    local result = CollectionUtils.filter(t, function(x) return x % 2 == 0 end)
    assert.same(result, {2, 4})
  end)
end)
