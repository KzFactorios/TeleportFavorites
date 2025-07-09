-- lookups_spec.lua
-- Tests for core/cache/lookups.lua
-- Covers single-player and multiplayer scenarios


local Lookups = require("core.cache.lookups")

-- Busted assertion aliases for LSP/linters
local function are_same(a, b, msg)
  if a ~= b then
    error((msg or "Assertion failed: values not equal") .. "\nExpected: " .. tostring(a) .. "\nActual:   " .. tostring(b), 2)
  end
end
local function is_true(v, msg)
  if not v then
    error((msg or "Assertion failed: value is not true") .. "\nActual: " .. tostring(v), 2)
  end
end
local function is_nil(v, msg)
  if v ~= nil then
    error((msg or "Assertion failed: value is not nil") .. "\nActual: " .. tostring(v), 2)
  end
end
local function has_error(fn, msg)
  local ok = pcall(fn)
  if ok then
    error((msg or "Assertion failed: function did not error as expected"), 2)
  end
end

-- Busted globals (for LSP/linters)
---@diagnostic disable: undefined-global


-- Mocks and fakes
local function fake_surface(index)
  return {
    index = index,
    name = "surface-" .. tostring(index),
    get_tile = function(self, x, y)
      return {
        collides_with = function() return false end
      }
    end
  }
end

local function fake_chart_tag(valid, position)
  return {
    valid = valid,
    position = position or {x=0, y=0},
    icon = "icon.png",
    destroy = function(self) self.valid = false end
  }
end


-- Persistent chart tag storage to simulate Factorio runtime
local persistent_chart_tags = {
  [1] = {}, -- surface 1
  [2] = {}, -- surface 2
}

-- Use the same format as Lookups/gps_utils: zero-padded, dot-separated, no prefix
local function gps_string(pos, surface_index)
  local function pad(n)
    return string.format("%03d", tonumber(n) or 0)
  end
  return pad(pos.x) .. "." .. pad(pos.y) .. "." .. tostring(surface_index)
end

local function fake_game_env()
  -- Prepopulate persistent chart tags for each surface
  persistent_chart_tags[1] = {}
  persistent_chart_tags[2] = {}
  -- Add a chart tag for surface 1
  local tag1 = fake_chart_tag(true, {x=1, y=2})
  persistent_chart_tags[1][gps_string(tag1.position, 1)] = tag1
  -- Add a chart tag for surface 2
  local tag2 = fake_chart_tag(true, {x=3, y=4})
  persistent_chart_tags[2][gps_string(tag2.position, 2)] = tag2

  _G.game = {
    surfaces = {
      [1] = fake_surface(1),
      [2] = fake_surface(2)
    },
    forces = {
      ["player"] = {
        find_chart_tags = function(surface)
          local tags = {}
          for _, tag in pairs(persistent_chart_tags[surface.index] or {}) do
            if tag.valid then table.insert(tags, tag) end
          end
          return tags
        end
      }
    }
  }
end

local function fake_gps_utils()
  package.loaded["core.utils.gps_utils"] = {
    gps_from_map_position = function(pos, surface_index)
      return gps_string(pos, surface_index)
    end,
    get_surface_index_from_gps = function(gps)
      local parts = {}
      for part in string.gmatch(gps, "[^,]+") do table.insert(parts, part) end
      return tonumber(parts[#parts]) or 1
    end
  }
end

local function fake_helpers()
  package.loaded["core.utils.basic_helpers"] = {
    normalize_index = function(idx) return tonumber(idx) end
  }
  package.loaded["core.utils.position_utils"] = {
    is_walkable_position = function(surface, pos) return true end
  }
  package.loaded["core.utils.error_handler"] = {
    debug_log = function(...) end
  }
end

-- Setup test environment
before_each(function()
  fake_game_env()
  fake_gps_utils()
  fake_helpers()
  _G.Lookups = nil
  _G["Lookups"] = nil
end)

describe("Lookups cache module", function()
  it("initializes cache and fetches chart tags", function()
    local cache = Lookups.init()
    are_same("table", type(cache))
    local tags = Lookups.get_chart_tag_cache(1)
    are_same("table", type(tags))
    is_true(#tags > 0)
  end)

  it("returns chart tag by gps", function()
    Lookups.init() -- Ensure cache is initialized from mock
    Lookups.get_chart_tag_cache(1) -- Force cache build for surface 1
    local gps = gps_string({x=1, y=2}, 1)
    -- Print the keys in the Lookups cache for surface 1
    local cache = _G["Lookups"] and _G["Lookups"].surfaces and _G["Lookups"].surfaces[1]
    if cache and cache.chart_tags_mapped_by_gps then
      print("[DEBUG] chart_tags_mapped_by_gps keys:", table.concat((function(t) local r = {}; for k in pairs(t) do table.insert(r, k); end; return r; end)(cache.chart_tags_mapped_by_gps), ", "))
    else
      print("[DEBUG] chart_tags_mapped_by_gps is nil")
    end
    print("[DEBUG] looking up gps:", gps)
    local tag = Lookups.get_chart_tag_by_gps(gps)
    print("[DEBUG] tag for gps:1,2,1:", tag)
    if not tag then
      print("[DEBUG] Lookups cache:", _G["Lookups"])
      print("[DEBUG] persistent_chart_tags[1]:", persistent_chart_tags[1])
    end
    are_same("table", type(tag), "Expected a table for chart tag, got " .. tostring(tag))
    is_true(tag and tag.valid, "Expected tag to be valid")
  end)

  it("removes chart tag from cache by gps", function()
    Lookups.init() -- Ensure cache is initialized from mock
    Lookups.get_chart_tag_cache(1) -- Force cache build for surface 1
    local gps = gps_string({x=1, y=2}, 1)
    local tag = Lookups.get_chart_tag_by_gps(gps)
    print("[DEBUG] tag before removal:", tag)
    are_same("table", type(tag), "Expected a table for chart tag before removal, got " .. tostring(tag))
    is_true(tag and tag.valid, "Expected tag to be valid before removal")
    -- Simulate removal in persistent mock
    persistent_chart_tags[1][gps] = nil
    -- Invalidate Lookups cache so it will refetch from persistent_chart_tags
    Lookups.clear_surface_cache_chart_tags(1)
    Lookups.remove_chart_tag_from_cache_by_gps(gps)
    local tag2 = Lookups.get_chart_tag_by_gps(gps)
    print("[DEBUG] tag after removal:", tag2)
    is_nil(tag2, "Expected tag to be nil after removal")
  end)

  it("clears all caches", function()
    Lookups.init()
    Lookups.clear_all_caches()
    are_same("table", type(_G["Lookups"]))
  end)

  it("handles invalid surface index gracefully", function()
    -- get_chart_tag_cache should error for invalid input
    has_error(function() Lookups.get_chart_tag_cache("not-a-number") end, "Expected error for invalid surface index")
    -- clear_surface_cache_chart_tags should not throw
    Lookups.clear_surface_cache_chart_tags("not-a-number")
  end)

  it("returns nil for empty or nil gps in get_chart_tag_by_gps", function()
    is_nil(Lookups.get_chart_tag_by_gps(""), "Expected nil for empty gps")
  end)

  it("returns nil for non-existent surface in get_chart_tag_by_gps", function()
    -- Use a GPS string with a surface index that does not exist
    local gps = "001.002.99" -- surface 99 does not exist in fake_game_env
    is_nil(Lookups.get_chart_tag_by_gps(gps), "Expected nil for non-existent surface")
  end)

  it("returns nil for invalid chart tag in get_chart_tag_by_gps", function()
    Lookups.init()
    Lookups.get_chart_tag_cache(1)
    local gps = gps_string({x=1, y=2}, 1)
    -- Invalidate the tag in the cache
    local cache = _G["Lookups"].surfaces[1]
    if cache and cache.chart_tags_mapped_by_gps then
      cache.chart_tags_mapped_by_gps[gps].valid = false
    end
    is_nil(Lookups.get_chart_tag_by_gps(gps), "Expected nil for invalid chart tag")
  end)

  it("returns early in remove_chart_tag_from_cache_by_gps for nil/empty gps", function()
    -- Should not throw
    Lookups.remove_chart_tag_from_cache_by_gps("")
  end)

  it("returns early in remove_chart_tag_from_cache_by_gps for missing chart tag", function()
    -- Should not throw
    Lookups.remove_chart_tag_from_cache_by_gps("999.999.1")
  end)

  it("handles chart_tag.destroy() failure gracefully in remove_chart_tag_from_cache_by_gps", function()
    Lookups.init()
    Lookups.get_chart_tag_cache(1)
    local gps = gps_string({x=1, y=2}, 1)
    -- Patch the destroy method to throw
    local cache = _G["Lookups"].surfaces[1]
    if cache and cache.chart_tags_mapped_by_gps then
      cache.chart_tags_mapped_by_gps[gps].destroy = function() error("destroy failed") end
    end
    -- Should not throw
    Lookups.remove_chart_tag_from_cache_by_gps(gps)
  end)

  it("handles non-walkable chart tag position in get_chart_tag_by_gps", function()
    -- Patch PositionUtils to return false for walkability
    package.loaded["core.utils.position_utils"] = {
      is_walkable_position = function() return false end
    }
    Lookups.init()
    Lookups.get_chart_tag_cache(1)
    local gps = gps_string({x=1, y=2}, 1)
    -- Should still return the tag (walkability only logs)
    local tag = Lookups.get_chart_tag_by_gps(gps)
    are_same("table", type(tag), "Expected a table for chart tag even if not walkable")
  end)
end)
