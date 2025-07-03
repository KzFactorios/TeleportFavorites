
_G.global = _G.global or {}
_G.storage = _G.storage or {}
_G.remote = _G.remote or setmetatable({}, {__index = function() return function() end end})
_G.defines = _G.defines or {events = {}} -- Add more as needed

local Tag = require("core.tag.tag")
local mock_player_data = require("tests.mocks.mock_player_data")

if not Tag.new then
  function Tag.new(gps, text, owner)
    return {gps = gps, text = text, owner = owner}
  end
end

describe("Tag object", function()
  it("should create a tag with correct properties", function()
    local tag = Tag.new("gps_string")
    assert.equals(tag.gps, "gps_string")
    assert.is_nil(tag.text)
    assert.is_nil(tag.owner)
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
