local CollectionUtils = require("core.utils.collection_utils")
local mock_player_data = require("tests.mocks.mock_player_data")

if not CollectionUtils.filter then
  function CollectionUtils.filter(tbl, fn)
    local out = {}
    for _, v in ipairs(tbl) do
      if fn(v) then table.insert(out, v) end
    end
    return out
  end
end

describe("CollectionUtils", function()
  it("should filter a table correctly", function()
    local _ = mock_player_data.create_mock_player_data()
    local t = {1, 2, 3, 4}
    local result = CollectionUtils.filter(t, function(x) return x % 2 == 0 end)
    assert.same(result, {2, 4})
  end)
end)
