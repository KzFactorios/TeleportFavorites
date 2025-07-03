local Cache = require("core.cache.cache")

describe("Cache module", function()
  it("should store and retrieve values", function()
    Cache.set("test_key", 123)
    assert.equals(Cache.get("test_key"), 123)
  end)

  it("should return nil for missing keys", function()
    assert.is_nil(Cache.get("nonexistent_key"))
  end)
end)
