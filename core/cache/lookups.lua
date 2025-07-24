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
local PositionUtils = require("core.utils.position_utils")
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

  -- Lazy loading: only fetch chart tags if cache doesn't exist or is empty
  if not cache.surfaces[surface_idx].chart_tags or #cache.surfaces[surface_idx].chart_tags == 0 then
    local surface = game.surfaces[surface_idx]
    if surface then
      cache.surfaces[surface_idx].chart_tags = game.forces["player"].find_chart_tags(surface) or {}
    else
      cache.surfaces[surface_idx].chart_tags = {}
    end
  end
  
  -- Lazy loading: only rebuild GPS mapping if not exists
  if not cache.surfaces[surface_idx].chart_tags_mapped_by_gps then
    cache.surfaces[surface_idx].chart_tags_mapped_by_gps = {}
    
    -- Only build GPS mapping if we have chart tags
    local chart_tags = cache.surfaces[surface_idx].chart_tags
    if chart_tags and #chart_tags > 0 then
      -- Rebuild the GPS mapping using functional approach
      local function build_gps_mapping(chart_tag)
        if chart_tag and chart_tag.valid and chart_tag.position and surface_idx then
          -- Ensure surface_idx is properly typed as uint
          local surface_index_uint = tonumber(surface_idx) --[[@as uint]]
          -- Cast to number for gps_from_map_position function
          local surface_index_number = surface_index_uint --[[@as number]]
          local gps = GPSUtils.gps_from_map_position(chart_tag.position, surface_index_number)
          if gps and gps ~= "" then
            cache.surfaces[surface_idx].chart_tags_mapped_by_gps[gps] = chart_tag
          end
        end
      end

      -- Process each chart tag with the mapping function
      for _, chart_tag in ipairs(chart_tags) do
        build_gps_mapping(chart_tag)
      end
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
  local cache = ensure_cache()
  if cache.surfaces[surface_idx] then
    cache.surfaces[surface_idx].chart_tags = nil  -- Set to nil to trigger refetch
    cache.surfaces[surface_idx].chart_tags_mapped_by_gps = nil  -- Set to nil to trigger rebuild
  end
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
  if not BasicHelpers.is_valid_gps(gps) then return nil end
  local surface_index = GPSUtils.get_surface_index_from_gps(gps)
  local surface = game.surfaces[surface_index]
  if not surface then return nil end

  local surface_cache = ensure_surface_cache(surface_index)
  if not surface_cache then return nil end
  local match_chart_tag = surface_cache.chart_tags_mapped_by_gps[gps] or nil
  
  ErrorHandler.debug_log("[LOOKUPS] get_chart_tag_by_gps", {
    gps = gps,
    surface_index = surface_index,
    chart_tag_found = match_chart_tag ~= nil,
    chart_tag_valid = match_chart_tag and (function()
      local valid_check_success, is_valid = pcall(function() return match_chart_tag.valid end)
      return valid_check_success and is_valid or false
    end)(),
    chart_tag_has_icon = match_chart_tag and (function()
      local valid_check_success, is_valid = pcall(function() return match_chart_tag.valid end)
      return valid_check_success and is_valid and match_chart_tag.icon ~= nil or false
    end)()
  })
  
  -- Return nil if chart tag is invalid
  if not match_chart_tag then
    return nil
  end
  
  -- Safely check chart tag validity
  local valid_check_success, is_valid = pcall(function() return match_chart_tag.valid end)
  if not valid_check_success or not is_valid then
    return nil
  end
  
  -- Optional walkability check with debug logging
  if match_chart_tag.position then
    local walkable = PositionUtils.is_walkable_position(surface, match_chart_tag.position)
    if not walkable then
      ErrorHandler.debug_log("Chart tag at GPS is not walkable", {gps = gps, position = match_chart_tag.position})
    end
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

---@class Lookups
---@field get_chart_tag_by_gps fun(gps: string): LuaCustomChartTag|nil
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
}
