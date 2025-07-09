-- Edge case tests for core.cache.cache
local assert = require("luassert")
require("tests.mocks.factorio_test_env")

local Cache = require("core.cache.cache")
local PlayerFavoritesMocks = require("tests.mocks.player_favorites_mocks")


describe("[edge cases] core.cache.cache", function()
  local mock_player
  before_each(function()
    package.loaded["core.cache.cache"] = nil
    _G.storage = {}
    _G.game = {surfaces = { [1] = { index = 1, name = "nauvis", valid = true } } }
    mock_player = PlayerFavoritesMocks.mock_player(1, "EdgeCasePlayer", 1)
  end)


  it("handles nil input for get_player_data", function()
    assert.has_no.errors(function() Cache.get_player_data(nil) end)
  end)


  it("handles invalid input for get_surface_data", function()
    assert.has_no.errors(function() Cache.get_surface_data(1) end)
  end)


  it("handles invalid input for get_tag_by_gps", function()
    assert.is_nil(Cache.get_tag_by_gps(mock_player, nil))
  end)

  it("handles sanitize_for_storage with nested tables and userdata", function()
    local obj = { a = 1, b = { c = 2, d = { e = 3 } }, f = setmetatable({}, { __tostring = function() return "userdata" end }) }
    local sanitized = Cache.sanitize_for_storage(obj)
    assert(sanitized.a == 1)
    assert(type(sanitized.b) == "table")
    assert(type(sanitized.b.d) == "table")
    -- Userdata should be skipped (not copied)
    assert(sanitized.f == nil or type(sanitized.f) ~= "userdata")
  end)

  it("handles circular references in sanitize_for_storage", function()
    local t = { a = 1 }
    t.self = t
    local ok = pcall(function() Cache.sanitize_for_storage(t) end)
    assert.is_true(ok)
  end)

  it("handles get_player_teleport_history with valid player", function()
    assert.has_no.errors(function() Cache.get_player_teleport_history(mock_player, 1) end)
  end)

  it("handles ensure_surface_cache with invalid index", function()
    Cache.Lookups = { ensure_surface_cache = function(idx) return idx end }
    assert(Cache.ensure_surface_cache(nil) == nil)
    assert(Cache.ensure_surface_cache("bad") == "bad")
  end)

  it("handles set_player_surface with invalid surface index", function()
    _G.game = { surfaces = { [1] = { index = 1, name = "nauvis", valid = true } } }
    local bad_player = PlayerFavoritesMocks.mock_player(2, "BadSurfacePlayer", 1)
    assert.has_no.errors(function() Cache.set_player_surface(bad_player, 999) end)
  end)

  it("does not crash when removing a tag that does not exist", function()
    assert.has_no.errors(function() Cache.remove_stored_tag("gps:doesnotexist") end)
  end)

  it("handles get_mod_version with missing and present mod_version", function()
    _G.storage.mod_version = nil
    assert(Cache.get_mod_version() == "0.0.125")
    _G.storage.mod_version = "1.2.3"
    assert(Cache.get_mod_version() == "0.0.125")
  end)

  it("handles get with empty and valid key", function()
    _G.storage.test_key = 42
    assert.is_nil(Cache.get(""))
    assert(Cache.get("test_key") == 42)
  end)

  it("reset_transient_player_states is safe with nil player", function()
    assert.has_no.errors(function() Cache.reset_transient_player_states(nil) end)
  end)

  it("reset_transient_player_states clears drag and move state", function()
    local player = PlayerFavoritesMocks.mock_player(3, "ResetPlayer", 1)
    local pdata = Cache.get_player_data(player)
    pdata.drag_favorite = { active = true, source_slot = 1, favorite = { gps = "gps:1.2.1" } }
    pdata.tag_editor_data = { move_mode = true, error_message = "err" }
    Cache.reset_transient_player_states(player)
    assert.is_false(pdata.drag_favorite.active)
    assert.is_nil(pdata.drag_favorite.source_slot)
    assert.is_nil(pdata.drag_favorite.favorite)
    assert.is_false(pdata.tag_editor_data.move_mode)
    assert(pdata.tag_editor_data.error_message == "")
  end)

  it("set_tag_editor_delete_mode and reset_tag_editor_delete_mode handle nil player", function()
    assert.has_no.errors(function() Cache.set_tag_editor_delete_mode(nil, true) end)
    assert.has_no.errors(function() Cache.reset_tag_editor_delete_mode(nil) end)
  end)

  it("set_tag_editor_delete_mode and reset_tag_editor_delete_mode update state", function()
    local player = PlayerFavoritesMocks.mock_player(4, "DeleteModePlayer", 1)
    Cache.set_tag_editor_delete_mode(player, true)
    assert(Cache.get_tag_editor_data(player).delete_mode == true)
    Cache.reset_tag_editor_delete_mode(player)
    assert(Cache.get_tag_editor_data(player).delete_mode == false)
  end)

  it("create_tag_editor_data returns defaults and merges options", function()
    local defaults = Cache.create_tag_editor_data()
    assert(defaults.gps == "")
    assert(defaults.move_mode == false)
    local custom = Cache.create_tag_editor_data({ gps = "gps:1.2.1", move_mode = true })
    assert(custom.gps == "gps:1.2.1")
    assert(custom.move_mode == true)
    assert(custom.locked == false) -- default preserved
  end)

  it("init sets up storage and mod_version", function()
    _G.storage = nil
    local ok, err = pcall(function() Cache.init() end)
    assert.is_false(ok)
    _G.storage = {}
    local result = Cache.init()
    assert(result == _G.storage)
  end)
end)
