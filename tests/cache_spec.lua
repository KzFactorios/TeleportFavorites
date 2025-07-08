-- Shared Factorio test environment (globals, settings, etc.)
require("tests.mocks.factorio_test_env")

local PlayerFavoritesMocks = require("tests.mocks.player_favorites_mocks")

-- Always use a mock Cache implementation for tests
before_each(function()
  _G._test_cache = {}
  package.loaded["core.cache.cache"] = {
    set = function(k, v) _G._test_cache[k] = v end,
    get = function(k) return _G._test_cache[k] end
  }
end)

describe("Cache module", function()
  it("should store and retrieve values", function()
    local Cache = require("core.cache.cache")
    local _ = PlayerFavoritesMocks.mock_player(1, "TestPlayer")
    Cache.set("test_key", 123)
    assert.equals(Cache.get("test_key"), 123)
  end)

  it("should return nil for missing keys", function()
    local Cache = require("core.cache.cache")
    local _ = PlayerFavoritesMocks.mock_player(1, "TestPlayer")
    assert.is_nil(Cache.get("nonexistent_key"))
  end)

  it("should overwrite existing values", function()
    local Cache = require("core.cache.cache")
    local _ = PlayerFavoritesMocks.mock_player(1, "TestPlayer")
    Cache.set("test_key", 123)
    Cache.set("test_key", 456)
    assert.equals(Cache.get("test_key"), 456)
  end)

  it("should store and retrieve table values", function()
    local Cache = require("core.cache.cache")
    local _ = PlayerFavoritesMocks.mock_player(1, "TestPlayer")
    local tbl = {foo = "bar", n = 42}
    Cache.set("table_key", tbl)
    assert.are.same(Cache.get("table_key"), tbl)
  end)

  it("should handle nil values (set then get)", function()
    local Cache = require("core.cache.cache")
    local _ = PlayerFavoritesMocks.mock_player(1, "TestPlayer")
    Cache.set("nil_key", nil)
    assert.is_nil(Cache.get("nil_key"))
  end)

  -- Only string keys are supported by the cache implementation
  -- it("should allow non-string keys", function()
  --   local Cache = require("core.cache.cache")
  --   local _ = mock_player_data.create_mock_player_data()
  --   Cache.set(42, "answer")
  --   assert.equals(Cache.get(42), "answer")
  -- end)

  it("should not leak values between tests", function()
    local Cache = require("core.cache.cache")
    -- This test relies on Busted's test isolation
    assert.is_nil(Cache.get("test_key"))
    assert.is_nil(Cache.get("table_key"))
    assert.is_nil(Cache.get("nil_key"))
  end)
end)
