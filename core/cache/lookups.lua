-- core/cache/lookups.lua
-- TeleportFavorites Factorio Mod
-- Manages runtime cache for chart tag lookups, rebuilt from game state for performance and multiplayer safety.
--
-- Runtime Lookups Structure:
-- _G.Lookups = {
--   surfaces = {
--     [surface_index] = {
--       gps_point_cache = { [gps_string] = { tag = LuaCustomChartTag, expires_at = uint } },
--       next_sweep_at   = uint   -- per-surface sweep clock (session-local, not storage)
--     }, ...
--   }
-- }
--
-- Design:
--   - Each GPS entry carries a TTL; touching an entry resets its timer (LRU-style expiry).
--   - No "false" sentinel: cache only stores positive hits; misses re-query cheaply via area query.
--   - Mutations evict only the affected GPS entry (surgical); full-surface wipes are gone.
--   - Periodic sweep removes expired entries only for surfaces with active players.
--     The sweep clock is per-surface and pauses when no players are on that surface.

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

-- TTL for each cached GPS→tag entry.  Touch-to-renew: every successful read resets this.
local TTL_TICKS   = 5 * 60 * 60          -- 5 minutes

-- Sweep cadence per surface: slightly longer than TTL so actively-used entries survive.
local SWEEP_TICKS = math.floor(TTL_TICKS * 1.1)  -- ~5.5 minutes (19,800 ticks)

--- Ensure the top-level cache table exists in _G.
---@return table cache
local function ensure_cache()
  _G[CACHE_KEY] = _G[CACHE_KEY] or {}
  local cache = _G[CACHE_KEY]
  cache.surfaces = cache.surfaces or {}
  return cache
end

--- Initialises the surface-level cache tables for surface_index (no Factorio API calls).
---@param surface_index number|string
---@return table surface_cache
local function ensure_surface_cache(surface_index)
  local surface_idx = BasicHelpers.normalize_index(surface_index)
  if not surface_idx then
    error("Invalid surface index: " .. tostring(surface_index))
  end
  local cache = ensure_cache()
  if not cache.surfaces[surface_idx] then
    cache.surfaces[surface_idx] = {
      gps_point_cache = {},
      next_sweep_at   = (game and game.tick or 0) + SWEEP_TICKS,
    }
  end
  cache.surfaces[surface_idx].gps_point_cache = cache.surfaces[surface_idx].gps_point_cache or {}
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

--- Evict a single GPS entry from the point cache (surgical invalidation for tag moves).
--- Called when a tag moves from old_gps → new_gps; old_gps entry is now stale.
---@param gps string
local function evict_chart_tag_cache_entry(gps)
  if not gps or gps == "" then return end
  local surface_index = GPSUtils.get_surface_index_from_gps(gps)
  if not surface_index then return end
  local surface_idx = BasicHelpers.normalize_index(surface_index)
  local cache = ensure_cache()
  local sc = cache.surfaces[surface_idx]
  if sc and sc.gps_point_cache then
    sc.gps_point_cache[gps] = nil
  end
end

--- Returns a LuaCustomChartTag by GPS string using a per-GPS area query (O(1)).
--- Results are cached with a TTL; each successful read resets the expiry (touch-to-renew).
--- No "false" sentinel: a miss simply returns nil and re-queries on next access.
---@param gps string
---@return LuaCustomChartTag|nil
local function get_chart_tag_by_gps(gps)
  if not BasicHelpers.is_valid_gps(gps) then return nil end
  local surface_index = GPSUtils.get_surface_index_from_gps(gps)
  local surface = game.surfaces[surface_index]
  if not surface then return nil end

  local surface_cache = ensure_surface_cache(surface_index)
  local point_cache   = surface_cache.gps_point_cache
  local now           = game.tick

  local entry = point_cache[gps]
  if entry ~= nil then
    -- Validity check: Factorio userdata becomes invalid when the tag is destroyed.
    local ok, is_valid = pcall(function() return entry.tag.valid end)
    if ok and is_valid and now < entry.expires_at then
      -- Hit: renew TTL so actively-used entries never expire.
      entry.expires_at = now + TTL_TICKS
      return entry.tag
    end
    -- Stale (expired or tag destroyed): evict and fall through to re-query.
    point_cache[gps] = nil
  end

  -- Cache miss: single O(1) area query via Factorio spatial index.
  local pos = GPSUtils.map_position_from_gps(gps)
  local tag = pos and lookup_chart_tag_by_area(surface, pos) or nil
  if tag then
    point_cache[gps] = { tag = tag, expires_at = now + TTL_TICKS }
  end
  -- No entry stored for not-found; next miss re-queries cheaply.

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

--- Sweep expired entries from gps_point_cache for all active surfaces.
--- Should be called from a permanent on_nth_tick handler.
--- Only sweeps surfaces that currently have at least one connected player (per-surface
--- sweep clock pauses while the surface is empty and resumes when players return).
local function sweep_expired_entries()
  if not game then return end
  local now = game.tick

  -- Build set of surface indices with active players.
  local active_surfaces = {}
  for _, player in pairs(game.connected_players) do
    if player and player.valid and player.surface then
      active_surfaces[player.surface.index] = true
    end
  end

  local cache = ensure_cache()
  for surface_idx, sc in pairs(cache.surfaces) do
    if active_surfaces[surface_idx] and sc.next_sweep_at and now >= sc.next_sweep_at then
      local point_cache = sc.gps_point_cache
      if point_cache then
        for gps, entry in pairs(point_cache) do
          if now >= entry.expires_at then
            point_cache[gps] = nil
          end
        end
      end
      sc.next_sweep_at = now + SWEEP_TICKS
      ErrorHandler.debug_log("[LOOKUPS] swept gps_point_cache", { surface_index = surface_idx, tick = now })
    end
  end
end

--- Seed the GPS point cache with a known-valid chart tag (no area query needed).
--- Call this from on_chart_tag_added to populate the cache from event.tag directly,
--- avoiding the redundant find_chart_tags area query that get_chart_tag_by_gps would trigger.
---@param gps string
---@param chart_tag LuaCustomChartTag
local function seed_chart_tag_in_cache(gps, chart_tag)
  if not gps or gps == "" then return end
  if not chart_tag then return end
  local ok, is_valid = pcall(function() return chart_tag.valid end)
  if not ok or not is_valid then return end
  local surface_index = GPSUtils.get_surface_index_from_gps(gps)
  if not surface_index then return end
  local surface_idx = BasicHelpers.normalize_index(surface_index)
  local cache = ensure_cache()
  local sc = cache.surfaces[surface_idx]
  if not sc then
    sc = { gps_point_cache = {}, next_sweep_at = (game and game.tick or 0) + SWEEP_TICKS }
    cache.surfaces[surface_idx] = sc
  end
  local now = game and game.tick or 0
  sc.gps_point_cache[gps] = { tag = chart_tag, expires_at = now + TTL_TICKS }
end

--- Destroy a chart tag by GPS and evict its cache entry.
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

  -- Surgical eviction: only remove this GPS entry, leave the rest of the surface intact.
  evict_chart_tag_cache_entry(gps)
end

---@class Lookups
---@field get_chart_tag_by_gps fun(gps: string): LuaCustomChartTag|nil
---@field seed_chart_tag_in_cache fun(gps: string, chart_tag: LuaCustomChartTag): nil
---@field evict_chart_tag_cache_entry fun(gps: string): nil
---@field sweep_expired_entries fun(): nil
---@field SWEEP_TICKS number
return {
  init                               = init,
  get_chart_tag_by_gps               = get_chart_tag_by_gps,
  seed_chart_tag_in_cache            = seed_chart_tag_in_cache,
  evict_chart_tag_cache_entry        = evict_chart_tag_cache_entry,
  sweep_expired_entries              = sweep_expired_entries,
  remove_chart_tag_from_cache_by_gps = remove_chart_tag_from_cache_by_gps,
  ensure_surface_cache               = ensure_surface_cache,
  -- kept for callers not yet migrated; treated as surgical eviction is a no-op
  -- (full-surface wipe no longer needed; callers will be updated)
  invalidate_surface_chart_tags      = function(surface_index)
    -- Legacy shim: previously wiped the full surface cache.
    -- Now a no-op placeholder; all callers should migrate to evict_chart_tag_cache_entry.
    ErrorHandler.debug_log("[LOOKUPS] invalidate_surface_chart_tags called (legacy shim)", { surface_index = surface_index })
  end,
  SWEEP_TICKS                        = SWEEP_TICKS,
}
