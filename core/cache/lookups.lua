-- core/cache/lookups.lua
-- TeleportFavorites Factorio Mod
-- Manages runtime cache for chart tag lookups, rebuilt from game state for performance and multiplayer safety.
--
-- Runtime Lookups Structure:
-- Lookups = {
--   surfaces = {
--     [surface_index] = {
--       chart_tags = { LuaCustomChartTag, ... },
--       chart_tags_mapped_by_gps = { [gps_string] = LuaCustomChartTag }
--     }, ...
--   }
-- }

---@diagnostic disable: undefined-global

local basic_helpers = require("core.utils.basic_helpers")
local GPSUtils = require("core.utils.gps_utils")
local ErrorHandler = require("core.utils.error_handler")
local BasicHelpers = require("core.utils.basic_helpers")

-- Handles the non-persistent in-game data cache for runtime lookups.
local Lookups = {}
Lookups.__index = Lookups
local CACHE_KEY = "Lookups"

--- Ensure the cache.surfaces table exists in global (non-persistent)
--- This is a local function and should never be called from outside this module.
--- It initializes the cache if it doesn't exist, ensuring a consistent structure.
--- @return table
local function ensure_cache()
  _G[CACHE_KEY] = _G[CACHE_KEY] or {}
  local cache = _G[CACHE_KEY]
  cache.surfaces = cache.surfaces or {}
  return cache
end

local function ensure_surface_cache(surface_index)
  local surface_idx = basic_helpers.normalize_index(surface_index)
  if not surface_idx then
    error("Invalid surface index: " .. tostring(surface_index))
  end
  local cache = ensure_cache()
  cache.surfaces[surface_idx] = cache.surfaces[surface_idx] or {}

  if not cache.surfaces[surface_idx].chart_tags_mapped_by_gps then
    cache.surfaces[surface_idx].chart_tags_mapped_by_gps = {}
    -- GPS map starts empty and is lazily warmed on first access (see warm_surface_gps_map).
  end

  return cache.surfaces[surface_idx]
end

--- Static method to be called once at the start of the game or when the mod is loaded.
--- It ensures that the global Lookups cache is initialized and ready for use.
--- @return table
local function init()
  return ensure_cache()
end

--- Static method to clear the Lookups.surfaces[surface_index].charts tags and it's map
--- It is useful when the chart tags for a surface have changed and need to be rebuilt.
local function clear_surface_cache_chart_tags(surface_index)
  if not surface_index then
    error("Invalid surface index: " .. tostring(surface_index))
  end
  local surface_idx = basic_helpers.normalize_index(surface_index)
  local cache = ensure_cache()
  if cache.surfaces[surface_idx] then
    cache.surfaces[surface_idx].chart_tags = nil  -- Set to nil to trigger refetch
    cache.surfaces[surface_idx].chart_tags_mapped_by_gps = nil  -- Set to nil to trigger rebuild
    cache.surfaces[surface_idx].chart_tags_gps_map_warmed = nil  -- Reset warm flag so next access re-warms
  end
end

--- Warm the GPS map for a surface by scanning all chart tags once.
--- After a game load the runtime GPS map is empty. The first call for each surface does a
--- find_chart_tags scan (one-time cost) so subsequent get_chart_tag_by_gps calls are O(1) hits
--- rather than cache misses that trigger false "invalid_chart_tag" notifications.
---@param surface_index number
local function warm_surface_gps_map(surface_index)
  local surface_idx = basic_helpers.normalize_index(surface_index)
  if not surface_idx then return end
  local surface_cache = ensure_surface_cache(surface_idx)
  if not surface_cache then return end
  if surface_cache.chart_tags_gps_map_warmed then return end
  surface_cache.chart_tags_gps_map_warmed = true  -- Set before scan to prevent re-entry

  local surface = game.surfaces[surface_idx]
  if not surface or not surface.valid then return end

  local all_tags = game.forces["player"].find_chart_tags(surface)
  local count = 0
  for _, tag in ipairs(all_tags) do
    if tag.valid and tag.position then
      local tag_gps = GPSUtils.gps_from_map_position(tag.position, surface_idx)
      if tag_gps then
        surface_cache.chart_tags_mapped_by_gps[tag_gps] = tag
        count = count + 1
      end
    end
  end
  ErrorHandler.debug_log("warm_surface_gps_map: complete", { surface_index = surface_idx, tags_cached = count })
end

local function get_chart_tag_cache(surface_index)
  local surface_idx = basic_helpers.normalize_index(surface_index)
  local surface_cache = ensure_surface_cache(surface_idx)
  
  -- Lazy-load chart_tags array only when this function is actually called (proximity search)
  -- This defers find_chart_tags() from initialization to right-click time
  if not surface_cache.chart_tags then
    local surface = game.surfaces[surface_idx]
    if surface then
      surface_cache.chart_tags = game.forces["player"].find_chart_tags(surface) or {}
    else
      surface_cache.chart_tags = {}
    end
    ErrorHandler.debug_log("get_chart_tag_cache: find_chart_tags scan", {
      surface_index = surface_idx,
      tags_found = #(surface_cache.chart_tags)
    })
  end
  
  return surface_cache.chart_tags or {}
end

--- Static method to fetch a LuaCustomChartTag by gps (O(1) lookup).
--- Self-healing: if the GPS map has not yet been warmed for this surface (e.g. after a
--- game load or surface switch), performs a one-time find_chart_tags scan on first miss
--- so subsequent lookups are O(1) hits rather than false cache misses.
---@param gps string
---@return LuaCustomChartTag|nil
local function get_chart_tag_by_gps(gps)
  if not BasicHelpers.is_valid_gps(gps) then return nil end
  local surface_index = GPSUtils.get_surface_index_from_gps(gps)
  local surface = game.surfaces[surface_index]
  if not surface then return nil end

  local surface_cache = ensure_surface_cache(surface_index)
  if not surface_cache then return nil end
  local match_chart_tag = surface_cache.chart_tags_mapped_by_gps[gps]

  -- Self-healing warm: if the map hasn't been scanned yet and we have a miss,
  -- do the one-time find_chart_tags scan and retry. This covers game-load and
  -- surface-switch scenarios without requiring callers to pre-warm explicitly.
  if not match_chart_tag and not surface_cache.chart_tags_gps_map_warmed then
    warm_surface_gps_map(surface_index)
    match_chart_tag = surface_cache.chart_tags_mapped_by_gps[gps]
  end

  if ErrorHandler.should_log_debug() then
    ErrorHandler.debug_log("[LOOKUPS] get_chart_tag_by_gps", {
      gps = gps,
      surface_index = surface_index,
      chart_tag_found = match_chart_tag ~= nil,
      chart_tag_valid = match_chart_tag and match_chart_tag.valid or false,
    })
  end

  if not match_chart_tag then return nil end
  -- Factorio's .valid never throws — direct access is safe.
  if not match_chart_tag.valid then return nil end

  return match_chart_tag
end

--- Selectivly remove a chart tag from the cache by GPS.
--- This is useful when a chart tag is deleted or modified and we want to ensure the cache is up-to-date.
---@param gps string
local function remove_chart_tag_from_cache_by_gps(gps)
  if not gps or gps == "" then return end
  local chart_tag = get_chart_tag_by_gps(gps)
  if not chart_tag then return end
  
  -- Only destroy the chart_tag if it's still valid (prevent double-destroy)
  -- Wrap in pcall to handle cases where chart_tag becomes invalid between check and destroy
  if chart_tag.valid then
    local success, error_msg = pcall(function()
      chart_tag.destroy()
    end)
    if not success then
      ErrorHandler.debug_log("Chart tag destroy failed in cache cleanup, but continuing", { error = error_msg })
    end
  end
  
  -- Reset the surface_cache_chart_tags regardless of chart_tag destruction success
  local surface_index = GPSUtils.get_surface_index_from_gps(gps)
  clear_surface_cache_chart_tags(surface_index)
end

--- Clear all lookup caches across all surfaces
--- This is useful when doing a complete cache reset
local function clear_all_caches()
  _G[CACHE_KEY] = nil
  ensure_cache()
end

--- UPS OPTIMIZATION: Update a single chart tag entry in the GPS mapping cache.
--- This avoids the expensive full cache invalidation + find_chart_tags() rescan.
---@param gps string GPS coordinate string
---@param chart_tag LuaCustomChartTag The chart tag to cache
local function upsert_chart_tag_in_cache(gps, chart_tag)
  if not gps or gps == "" then return end
  if not chart_tag then return end

  local surface_index = GPSUtils.get_surface_index_from_gps(gps)
  local surface_idx = basic_helpers.normalize_index(surface_index)
  if not surface_idx then return end

  local cache = ensure_cache()
  if not cache.surfaces[surface_idx] then
    -- Surface cache doesn't exist yet — will be lazily built on next full access
    return
  end

  -- Update GPS mapping directly (O(1) operation)
  if cache.surfaces[surface_idx].chart_tags_mapped_by_gps then
    cache.surfaces[surface_idx].chart_tags_mapped_by_gps[gps] = chart_tag
  end
end

--- UPS OPTIMIZATION: Remove a single chart tag entry from the GPS mapping cache.
--- This avoids the expensive full cache invalidation + find_chart_tags() rescan.
---@param gps string GPS coordinate string to remove
local function evict_chart_tag_from_cache(gps)
  if not gps or gps == "" then return end

  local surface_index = GPSUtils.get_surface_index_from_gps(gps)
  local surface_idx = basic_helpers.normalize_index(surface_index)
  if not surface_idx then return end

  local cache = ensure_cache()
  if not cache.surfaces[surface_idx] then return end

  -- Remove from GPS mapping (O(1) operation)
  if cache.surfaces[surface_idx].chart_tags_mapped_by_gps then
    cache.surfaces[surface_idx].chart_tags_mapped_by_gps[gps] = nil
  end
end

---@class Lookups
---@field get_chart_tag_by_gps fun(gps: string): LuaCustomChartTag|nil
---@field upsert_chart_tag_in_cache fun(gps: string, chart_tag: LuaCustomChartTag)
---@field evict_chart_tag_from_cache fun(gps: string)
---@field warm_surface_gps_map fun(surface_index: number)
return {
  init = init,
  get_chart_tag_cache = get_chart_tag_cache,
  get_surface_chart_tags = get_chart_tag_cache, -- Alias for consistency
  get_chart_tag_by_gps = get_chart_tag_by_gps,
  clear_surface_cache_chart_tags = clear_surface_cache_chart_tags,
  invalidate_surface_chart_tags = clear_surface_cache_chart_tags, -- Alias for consistency
  remove_chart_tag_from_cache_by_gps = remove_chart_tag_from_cache_by_gps,
  clear_all_caches = clear_all_caches,
  ensure_surface_cache = ensure_surface_cache,
  upsert_chart_tag_in_cache = upsert_chart_tag_in_cache,
  evict_chart_tag_from_cache = evict_chart_tag_from_cache,
  warm_surface_gps_map = warm_surface_gps_map,
}
