
local mock_player_data = require("tests.mocks.mock_player_data")

describe("Data Viewer per-player settings", function()
  it("should have default font size", function()
    local mock = mock_player_data.create_mock_player_data()
    local player = mock.players[1]
    assert.equals(player.data_viewer_settings.font_size, 12)
  end)
end)
