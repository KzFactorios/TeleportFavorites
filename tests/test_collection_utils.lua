local CollectionUtils = require("core.utils.collection_utils")

describe("CollectionUtils", function()
  it("should filter a table correctly", function()
    local t = {1, 2, 3, 4}
    local result = CollectionUtils.filter(t, function(x) return x % 2 == 0 end)
    assert.same(result, {2, 4})
  end)
end)
