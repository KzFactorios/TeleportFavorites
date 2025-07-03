
local Favorite = require("core.favorite.favorite")
local mock_player_data = require("tests.mocks.mock_player_data")

describe("Favorite object", function()
  it("should create a favorite with correct properties", function()
    local fav = Favorite.new("gps_string", "icon_name", "label")
    assert.equals(fav.gps, "gps_string")
    assert.equals(fav.icon, "icon_name")
    assert.equals(fav.label, "label")
  end)

  it("should integrate with mock player favorites", function()
    local mock = mock_player_data.create_mock_player_data({
      tag_ids = {"tag1", "tag2", "tag3"},
      player_names = {"TestPlayer"},
      favorites_config = {single_cases = {3}}
    })
    local favs = mock.favorites["TestPlayer_3"]
    assert.is_table(favs)
    assert.equals(#favs, 3)
    for _, tag_id in ipairs(favs) do
      assert.is_string(tag_id)
    end
  end)
end)
