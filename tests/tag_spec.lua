
local Tag = require("core.tag.tag")
local mock_player_data = require("tests.mocks.mock_player_data")

describe("Tag object", function()
  it("should create a tag with correct properties", function()
    local tag = Tag.new("gps_string", "text", "owner")
    assert.equals(tag.gps, "gps_string")
    assert.equals(tag.text, "text")
    assert.equals(tag.owner, "owner")
  end)

  it("should integrate with mock player data for tags", function()
    local mock = mock_player_data.create_mock_player_data({
      tag_ids = {"tagA", "tagB"},
      player_names = {"TagTester"},
      favorites_config = {single_cases = {2}}
    })
    local favs = mock.favorites["TagTester_2"]
    assert.is_table(favs)
    assert.equals(#favs, 2)
    for _, tag_id in ipairs(favs) do
      assert.is_string(tag_id)
    end
  end)
end)
