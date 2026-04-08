-- core/cache/lookups.lua
-- TeleportFavorites Factorio Mod
-- Manages runtime cache for chart tag lookups, rebuilt from game state for performance and multiplayer safety.
--
-- Runtime Lookups Structure:
-- Lookups = {
--   surfaces = {
--     [surface_index] = {
--       chart_tags      = { LuaCustomChartTag, ... },            -- full list (lazy, tag editor only)
--       gps_point_cache = { [gps_string] = LuaCustomChartTag|false }  -- per-GPS area-query cache
--     }, ...
--   }
-- }

---@diagnostic disable: undefined-global

local Deps = require("base_deps")
local BasicHelpers, ErrorHandler, GPSUtils =
  Deps.BasicHelpers, Deps.ErrorHandler, Deps.GpsUtils

local Lookups = {}
Lookups.__index = Lookups
local CACHE_KEY = "Lookups"

-- Half-tile bounding box used for targeted area queries.
-- Keeps the query tight enough to avoid catching adjacent tags while tolerating
-- the integer-rounding done by gps_from_map_position.
local GPS_EPSILON = 0.25

--- Ensure the top-level cache table exists in _G.
---@return table cache
local function ensure_cache()
  _G[CACHE_KEY] = _G[CACHE_KEY] or {}
  local cache = _G[CACHE_KEY]
  cache.surfaces = cache.surfaces or {}
  return cache
end

--- Initialises the surface-level cache tables for surface_index.
--- Does NOT perform a full find_chart_tags() scan; that cost is deferred to
--- get_chart_tag_cache() which is only called by the tag editor / click-detection paths.
---@param surface_index number|string
---@return table surface_cache
local function ensure_surface_cache(surface_index)
  local surface_idx = BasicHelpers.normalize_index(surface_index)
  if not surface_idx then
    error("Invalid surface index: " .. tostring(surface_index))
  end
  local cache = ensure_cache()
  cache.surfaces[surface_idx] = cache.surfaces[surface_idx] or {}
  cache.surfaces[surface_idx].gps_point_cache =
    cache.surfaces[surface_idx].gps_point_cache or {}
  return cache.surfaces[surface_idx]
end

--- O(1) targeted area query for a single map position.
--- find_chart_tags(surface, area) uses Factorio's spatial index; with a half-tile
--- bounding box it returns at most the one tag sitting at that position.
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

---@return table
local function init()
  return ensure_cache()
end

--- Invalidate all chart-tag caches for a surface (called on tag add/remove/modify).
---@param surface_index number|string
local function clear_surface_cache_chart_tags(surface_index)
  if not surface_index then
    error("Invalid surface index: " .. tostring(surface_index))
  end
  local surface_idx = BasicHelpers.normalize_index(surface_index)
  local cache = ensure_cache()
  if cache.surfaces[surface_idx] then
    cache.surfaces[surface_idx].chart_tags              = nil
    cache.surfaces[surface_idx].chart_tags_mapped_by_gps = nil
    cache.surfaces[surface_idx].gps_point_cache         = nil
  end
end

--- Returns the full list of chart tags for a surface (lazy, O(all_tags) scan).
--- Only called by the tag editor and click-detection; never during startup hydration.
---@param surface_index number|string
---@return LuaCustomChartTag[]
local function get_chart_tag_cache(surface_index)
  local surface_idx   = BasicHelpers.normalize_index(surface_index)
  local surface_cache = ensure_surface_cache(surface_idx)
  if not surface_cache.chart_tags or #surface_cache.chart_tags == 0 then
    local surface = game.surfaces[surface_idx]
    surface_cache.chart_tags =
      surface and game.forces["player"].find_chart_tags(surface) or {}
  end
  return surface_cache.chart_tags or {}
end

--- Returns a LuaCustomChartTag by GPS string using a per-GPS area query (O(1)).
--- Results are stored in gps_point_cache; `false` means "queried, not found".
--- The full-surface scan path (get_chart_tag_cache) is intentionally not touched here.
---@param gps string
---@return LuaCustomChartTag|nil
local function get_chart_tag_by_gps(gps)
  if not BasicHelpers.is_valid_gps(gps) then return nil end
  local surface_index = GPSUtils.get_surface_index_from_gps(gps)
  local surface = game.surfaces[surface_index]
  if not surface then return nil end

  local surface_cache = ensure_surface_cache(surface_index)
  local point_cache   = surface_cache.gps_point_cache

  local cached = point_cache[gps]
  if cached ~= nil then
    -- false == "looked up previously, no tag at this GPS"
    if cached == false then return nil end
    local ok, is_valid = pcall(function() return cached.valid end)
    if ok and is_valid then return cached end
    -- Stale: the tag was destroyed since the last lookup — re-query
    point_cache[gps] = nil
  end

  -- Cache miss: single O(1) area query
  local pos = GPSUtils.map_position_from_gps(gps)
  local tag = pos and lookup_chart_tag_by_area(surface, pos) or nil
  point_cache[gps] = tag or false

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

--- Destroy a chart tag by GPS and invalidate the surface cache.
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

  local surface_index = GPSUtils.get_surface_index_from_gps(gps)
  clear_surface_cache_chart_tags(surface_index)
end

---@class Lookups
---@field get_chart_tag_by_gps fun(gps: string): LuaCustomChartTag|nil
return {
  init                          = init,
  get_chart_tag_cache           = get_chart_tag_cache,
  get_chart_tag_by_gps          = get_chart_tag_by_gps,
  clear_surface_cache_chart_tags = clear_surface_cache_chart_tags,
  invalidate_surface_chart_tags  = clear_surface_cache_chart_tags,
  remove_chart_tag_from_cache_by_gps = remove_chart_tag_from_cache_by_gps,
  ensure_surface_cache          = ensure_surface_cache,
}
