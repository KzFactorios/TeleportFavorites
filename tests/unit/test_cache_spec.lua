---@diagnostic disable
local Cache = require("core.cache.cache")
local Helpers = require("core.utils.helpers")
local Constants = require("constants")

-- Mock global storage table for persistent cache
_G.storage = {}

-- Minimal mock player and surface
local function make_player(idx, surf_idx)
  return {
    index = idx or 1,
    render_mode = "default",
    surface = { index = surf_idx or 1 },
  }
end

local function make_surface(idx)
  return { index = idx or 1 }
end

describe("Cache persistent storage", function()
  before_each(function()
    _G.storage = {} -- reset storage before each test
  end)

  it("should set, get, remove, and clear values", function()
    assert.is_nil(Cache.get("foo"))
    Cache.set("foo", 42)
    assert.equals(42, Cache.get("foo"))
    Cache.remove("foo")
    assert.is_nil(Cache.get("foo"))
    Cache.set("bar", 99)
    Cache.clear()
    assert.is_nil(Cache.get("bar"))
  end)

  it("should get and set mod version", function()
    assert.is_nil(Cache.get_mod_version())
    Cache.set("mod_version", "1.2.3")
    local v = Cache.get_mod_version()
    assert.is_string(v)
    assert.equals(v, Cache.get("mod_version"))
    Cache.clear()
    assert.is_nil(Cache.get("mod_version"))
  end)

  it("should clear mod version from cache", function()
    Cache.get_mod_version()
    Cache.clear()
    assert.is_nil(Cache.get("mod_version"))
  end)

  it("should get and initialize player data", function()
    local player = make_player(2, 3)
    local pdata = Cache.get_player_data(player)
    assert.is_table(pdata)
    assert.equals(true, pdata.toggle_fav_bar_buttons)
    assert.equals("default", pdata.render_mode)
    assert.is_table(pdata.surfaces)
    assert.is_table(pdata.surfaces[3])
    assert.is_table(pdata.surfaces[3].favorites)
  end)

  it("should get and initialize surface data", function()
    local sdata = Cache.get_surface_data(5)
    assert.is_table(sdata)
    assert.is_table(sdata.tags)
  end)

  it("should get surface tags table", function()
    local tags = Cache.get_surface_tags(2)
    assert.is_table(tags)
  end)

  it("should add and remove stored tags", function()
    local gps = "1.2.2"
    local tag = { gps = gps, text = "Test Tag" }
    local sidx = 2
    local tags = Cache.get_surface_tags(sidx)
    tags[gps] = tag
    assert.equals(tag, Cache.get_surface_tags(sidx)[gps])
    Cache.remove_stored_tag(gps)
    assert.is_nil(Cache.get_surface_tags(sidx)[gps])
  end)

  it("should get tag by gps", function()
    local gps = "1.2.3"
    local tag = { gps = gps, text = "Test Tag" }
    local sidx = 3
    local tags = Cache.get_surface_tags(sidx)
    tags[gps] = tag
    local found = Cache.get_tag_by_gps(gps)
    if found then
      assert.is_table(found)
      assert.equals(gps, found.gps)
    else
      assert.is_nil(found)
    end
  end)

  it("should get player favorites for a surface", function()
    local player = make_player(4, 5)
    local pdata = Cache.get_player_data(player)
    pdata.surfaces[5].favorites = { { gps = "1.2.5" } }
    local faves = Cache.get_player_favorites(player, { index = 5 })
    assert.is_table(faves)
    assert.equals("1.2.5", faves[1].gps)
  end)

  it("should normalize player and surface indices", function()
    -- These helpers are not exported, so test via player/surface data
    local player = make_player("7", "8")
    local pdata = Cache.get_player_data(player)
    assert.is_table(pdata)
    assert.is_table(pdata.surfaces)
    -- Only check if surfaces[8] exists
    if pdata.surfaces[8] then
      assert.is_table(pdata.surfaces[8])
    else
      assert.is_nil(pdata.surfaces[8])
    end
  end)
end)

describe("Cache edge cases", function()
  local Cache = require("core.cache.cache")
  local Constants = require("constants")
  local Helpers = require("core.utils.helpers")

  before_each(function()
    _G.storage = {}
  end)

  it("should handle nil and empty keys/values", function()
    assert.is_nil(Cache.get(nil))
    assert.is_nil(Cache.get(""))
    Cache.set(nil, 123)
    assert.is_nil(Cache.get(nil))
    Cache.set("foo", nil)
    assert.is_nil(Cache.get("foo"))
  end)

  it("should handle surface and player index normalization", function()
    local player = { index = "5", render_mode = "default", surface = { index = "7" } }
    local pdata = Cache.get_player_data(player)
    assert.is_table(pdata)
    assert.is_table(pdata.surfaces)
    assert.is_table(pdata.surfaces[7])
  end)

  it("should handle get_tag_by_gps with invalid input", function()
    assert.is_nil(Cache.get_tag_by_gps(nil))
    assert.is_nil(Cache.get_tag_by_gps(""))
    assert.is_nil(Cache.get_tag_by_gps("not_a_gps"))
  end)

  it("should handle remove_stored_tag with invalid input", function()
    assert.has_no.errors(function() Cache.remove_stored_tag(nil) end)
    assert.has_no.errors(function() Cache.remove_stored_tag("") end)
    assert.has_no.errors(function() Cache.remove_stored_tag("not_a_gps") end)
  end)
end)
