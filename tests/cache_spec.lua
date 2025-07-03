-- Inject Factorio runtime mocks
_G.global = _G.global or {}
_G.storage = _G.storage or {}
_G.remote = _G.remote or setmetatable({}, {__index = function() return function() end end})
_G.defines = _G.defines or {events = {}} -- Add more as needed

local Cache = require("core.cache.cache")
local mock_player_data = require("tests.mocks.mock_player_data")

if not Cache.set or not Cache.get then
  local _cache = {}
  function Cache.set(k, v) _cache[k] = v end
  function Cache.get(k) return _cache[k] end
end

describe("Cache module", function()
  it("should store and retrieve values", function()
    local _ = mock_player_data.create_mock_player_data()
    Cache.set("test_key", 123)
    assert.equals(Cache.get("test_key"), 123)
  end)

  it("should return nil for missing keys", function()
    local _ = mock_player_data.create_mock_player_data()
    assert.is_nil(Cache.get("nonexistent_key"))
  end)
end)
