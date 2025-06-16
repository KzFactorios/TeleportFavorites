---@diagnostic disable: undefined-global

--[[
TeleportFavorites – Lookups Cache Module
========================================
Handles the non-persistent, runtime in-game data cache for fast lookups of chart tags and related objects.

- All cache data is stored in the global table under the key 'Lookups'.
- Provides O(1) lookup for chart tags by GPS string and surface index.
- Used for efficient access to chart tags, tag caches, and related runtime data.
- Not persistent: rebuilt as needed from game state.

Data Structure:
---------------
global["Lookups"] = {
  surfaces = {
    [surface_index] = {
      chart_tags = { ... },         -- Array of LuaCustomChartTag objects
      chart_tags_mapped_by_gps = { ... },  -- Map: gps string -> LuaCustomChartTag
    },
    ...
  },
  ...
}
--]]

local basic_helpers = require("core.utils.basic_helpers")
local PositionUtils = require("core.utils.position_utils")
local GPSUtils = require("core.utils.gps_utils")


---@diagnostic disable: undefined-global
---@class Lookups
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

  -- Only fetch chart tags if the cache is empty
  if not cache.surfaces[surface_idx].chart_tags then
    local surface = game.surfaces[surface_idx]
    if surface then
      cache.surfaces[surface_idx].chart_tags = game.forces["player"].find_chart_tags(surface) or {}
    else
      cache.surfaces[surface_idx].chart_tags = {}
    end
    cache.surfaces[surface_idx].chart_tags_mapped_by_gps = {}
  end

  -- Only rebuild the GPS map if it's empty and we have chart tags
  if not cache.surfaces[surface_idx].chart_tags_mapped_by_gps then
    cache.surfaces[surface_idx].chart_tags_mapped_by_gps = {}
  end
  -- Check if we need to rebuild the GPS mapping (avoid using # on tables)
  local chart_tags = cache.surfaces[surface_idx].chart_tags
  local gps_map = cache.surfaces[surface_idx].chart_tags_mapped_by_gps
  local map_count = 0
  for _ in pairs(gps_map) do map_count = map_count + 1 end  if #chart_tags > 0 and map_count == 0 then
    -- Rebuild the GPS mapping using functional approach
    local function build_gps_mapping(chart_tag)
      if chart_tag and chart_tag.valid and chart_tag.position and surface_idx then
        -- Ensure surface_idx is properly typed as uint
        local surface_index_uint = tonumber(surface_idx) --[[@as uint]]
        -- Cast to number for gps_from_map_position function
        local surface_index_number = surface_index_uint --[[@as number]]
        local gps = GPSUtils.gps_from_map_position(chart_tag.position, surface_index_number)
        if gps and gps ~= "" then
          gps_map[gps] = chart_tag
        end
      end
    end

    -- Process each chart tag with the mapping function
    for _, chart_tag in ipairs(chart_tags) do
      build_gps_mapping(chart_tag)
    end
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
  local surface_cache = ensure_surface_cache(surface_idx)
  surface_cache.chart_tags = {}
  surface_cache.chart_tags_mapped_by_gps = {}
  return surface_cache
end

--- Ensure the surfaces cache exists and initializes it if not.
--- @param surface_index number|string
--- @return LuaCustomChartTag[] -- Returns an array of LuaCustomChartTag objects
local function get_chart_tag_cache(surface_index)
  local surface_idx = basic_helpers.normalize_index(surface_index)
  local surface_cache = ensure_surface_cache(surface_idx)
  return surface_cache.chart_tags or {}
end

--- Static method to fetch a LuaCustomChartTag by gps (O(1) lookup)
--- uses the
---@param gps string
---@return LuaCustomChartTag|nil
local function get_chart_tag_by_gps(gps)
  if not gps or gps == "" then return nil end
  local surface_index = GPSUtils.get_surface_index_from_gps(gps)
  local surface_cache = ensure_surface_cache(surface_index)
  if not surface_cache then return nil end
  local match_chart_tag = surface_cache.chart_tags_mapped_by_gps[gps] or nil
  if (match_chart_tag and not match_chart_tag.valid) or
      (match_chart_tag and match_chart_tag.surface and not PositionUtils.is_walkable_position(match_chart_tag.surface, match_chart_tag.position)) then
    match_chart_tag = nil
  end
  return match_chart_tag
end


--- Selectivly remove a chart tag from the cache by GPS.
--- This is useful when a chart tag is deleted or modified and we want to ensure the cache is up-to-date.
---@param gps string
local function remove_chart_tag_from_cache_by_gps(gps)
  if not gps or gps == "" then return end
  local chart_tag = get_chart_tag_by_gps(gps)
  if not chart_tag then return end
  -- destroy the matching chart_tag object
  chart_tag.destroy()
  --reset the surface_cache_chart_tags
  local surface_index = GPSUtils.get_surface_index_from_gps(gps)
  clear_surface_cache_chart_tags(surface_index)
end

--- Clear all lookup caches across all surfaces
--- This is useful when doing a complete cache reset
local function clear_all_caches()
  _G[CACHE_KEY] = nil
  ensure_cache()
end


return {
  init = init,
  get_chart_tag_cache = get_chart_tag_cache,
  get_chart_tag_by_gps = get_chart_tag_by_gps,
  clear_surface_cache_chart_tags = clear_surface_cache_chart_tags,
  remove_chart_tag_from_cache_by_gps = remove_chart_tag_from_cache_by_gps,
  clear_all_caches = clear_all_caches,
}
