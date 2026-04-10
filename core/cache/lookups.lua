-- core/cache/lookups.lua
-- TeleportFavorites Factorio Mod
-- Session-local chart tag cache: tag_number ↔ LuaCustomChartTag, plus gps → tag_number.
-- tag_number is unique per force; this mod uses game.forces["player"] for area queries (single-force assumption).
--
-- _G.Lookups = {
--   tags = { [tag_number] = { tag = LuaCustomChartTag, gps = string } },
--   gps_to_tag_number = { [gps_string] = tag_number },
-- }

---@diagnostic disable: undefined-global

local Deps = require("base_deps")
local BasicHelpers, ErrorHandler, GPSUtils =
  Deps.BasicHelpers, Deps.ErrorHandler, Deps.GpsUtils

local CACHE_KEY = "Lookups"

-- Half-tile bounding box for cache-miss area queries only (not used on cache hits).
local GPS_EPSILON = 0.25

-- Periodic cleanup of entries whose LuaCustomChartTag userdata is no longer valid.
local VALIDITY_SWEEP_TICKS = 18000 -- 5 minutes at 60 UPS

---@return table cache
local function ensure_cache()
  _G[CACHE_KEY] = _G[CACHE_KEY] or {}
  local c = _G[CACHE_KEY]
  c.tags = c.tags or {}
  c.gps_to_tag_number = c.gps_to_tag_number or {}
  return c
end

--- Legacy API: storage/cache layers still call this to ensure surface tables exist in storage.
--- The tag_number cache no longer uses per-surface buckets; return an empty placeholder table.
---@param surface_index number|string
---@return table
local function ensure_surface_cache(surface_index)
  local surface_idx = BasicHelpers.normalize_index(surface_index)
  if not surface_idx then
    error("Invalid surface index: " .. tostring(surface_index))
  end
  return {}
end

---@param surface LuaSurface
---@param pos MapPosition
---@return LuaCustomChartTag|nil
local function lookup_chart_tag_by_area(surface, pos)
  local tags = game.forces["player"].find_chart_tags(surface, {
    left_top     = { x = pos.x - GPS_EPSILON, y = pos.y - GPS_EPSILON },
    right_bottom = { x = pos.x + GPS_EPSILON, y = pos.y + GPS_EPSILON },
  })
  return tags[1]
end

local function init()
  return ensure_cache()
end

---@param gps string
local function evict_chart_tag_cache_entry(gps)
  if not gps or gps == "" then return end
  local cache = ensure_cache()
  local tn = cache.gps_to_tag_number[gps]
  if tn then
    cache.tags[tn] = nil
  end
  cache.gps_to_tag_number[gps] = nil
end

---@param gps string
---@return LuaCustomChartTag|nil
local function get_chart_tag_by_gps(gps)
  if not BasicHelpers.is_valid_gps(gps) then return nil end
  local surface_index = GPSUtils.get_surface_index_from_gps(gps)
  local surface = game.surfaces[surface_index]
  if not surface then return nil end

  ensure_surface_cache(surface_index)

  local cache = ensure_cache()
  local tn = cache.gps_to_tag_number[gps]
  if tn ~= nil then
    local entry = cache.tags[tn]
    if entry and entry.tag and entry.tag.valid then
      return entry.tag
    end
    cache.gps_to_tag_number[gps] = nil
    if entry then cache.tags[tn] = nil end
  end

  local pos = GPSUtils.map_position_from_gps(gps)
  local tag = pos and lookup_chart_tag_by_area(surface, pos) or nil
  if tag and tag.valid then
    local tnum = tag.tag_number
    local old = cache.tags[tnum]
    if old and old.gps and old.gps ~= gps then
      cache.gps_to_tag_number[old.gps] = nil
    end
    cache.tags[tnum] = { tag = tag, gps = gps }
    cache.gps_to_tag_number[gps] = tnum
  end

  if ErrorHandler.should_log_debug() then
    ErrorHandler.debug_log("[LOOKUPS] get_chart_tag_by_gps", {
      gps             = gps,
      surface_index   = surface_index,
      chart_tag_found = tag ~= nil,
      chart_tag_valid = tag and tag.valid or false,
    })
  end

  return tag
end

local function sweep_expired_entries()
  if not game then return end
  local cache = ensure_cache()
  for tn, entry in pairs(cache.tags) do
    if not entry or not entry.tag or not entry.tag.valid then
      if entry and entry.gps then
        cache.gps_to_tag_number[entry.gps] = nil
      end
      cache.tags[tn] = nil
    end
  end
  if ErrorHandler.should_log_debug() then
    ErrorHandler.debug_log("[LOOKUPS] validity sweep", { tick = game.tick })
  end
end

---@param gps string
---@param chart_tag LuaCustomChartTag
local function seed_chart_tag_in_cache(gps, chart_tag)
  if not gps or gps == "" then return end
  if not chart_tag or not chart_tag.valid then return end
  local tn = chart_tag.tag_number
  local cache = ensure_cache()
  local old = cache.tags[tn]
  if old and old.gps and old.gps ~= gps then
    cache.gps_to_tag_number[old.gps] = nil
  end
  cache.tags[tn] = { tag = chart_tag, gps = gps }
  cache.gps_to_tag_number[gps] = tn
end

---@param gps string
local function remove_chart_tag_from_cache_by_gps(gps)
  if not gps or gps == "" then return end
  local chart_tag = get_chart_tag_by_gps(gps)
  if not chart_tag then return end

  if chart_tag.valid then
    local success, error_msg = pcall(function() chart_tag.destroy() end)
    if not success then
      ErrorHandler.debug_log("Chart tag destroy failed in cache cleanup, but continuing",
        { error = error_msg })
    end
  end

  evict_chart_tag_cache_entry(gps)
end

return {
  init                               = init,
  get_chart_tag_by_gps               = get_chart_tag_by_gps,
  seed_chart_tag_in_cache            = seed_chart_tag_in_cache,
  evict_chart_tag_cache_entry        = evict_chart_tag_cache_entry,
  sweep_expired_entries              = sweep_expired_entries,
  remove_chart_tag_from_cache_by_gps = remove_chart_tag_from_cache_by_gps,
  ensure_surface_cache               = ensure_surface_cache,
  invalidate_surface_chart_tags      = function(surface_index)
    ErrorHandler.debug_log("[LOOKUPS] invalidate_surface_chart_tags called (legacy shim)", { surface_index = surface_index })
  end,
  VALIDITY_SWEEP_TICKS               = VALIDITY_SWEEP_TICKS,
  -- Alias for older call sites / tests
  SWEEP_TICKS                        = VALIDITY_SWEEP_TICKS,
}
