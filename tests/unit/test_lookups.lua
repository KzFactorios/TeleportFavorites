-- tests/unit/test_lookups.lua
-- Unit tests for core.cache.lookups
local Lookups = require("core.cache.lookups")

local function test_cache_set_get_remove()
  Lookups.set("foo", 123)
  assert(Lookups.get("foo") == 123, "Should get value just set")
  Lookups.remove("foo")
  assert(Lookups.get("foo") == nil, "Should remove value")
end

local function test_surface_cache()
  local surface_index = 1
  local cache = Lookups.ensure_surface_cache(surface_index)
  assert(type(cache) == "table", "Should return a table for surface cache")
  assert(cache.chart_tags, "Should have chart_tags table")
  assert(cache.tag_editor_positions, "Should have tag_editor_positions table")
end

local function run_all()
  test_cache_set_get_remove()
  test_surface_cache()
  print("All Lookups tests passed.")
end

run_all()
