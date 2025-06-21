--[[
core/tag/tag_registry.lua
TeleportFavorites Factorio Mod
-----------------------------
Centralized registry for managing tag-related data access.

- Breaks circular dependencies between Tag, Cache, and Lookups modules
- Provides a single source of truth for tag data access and manipulation
- Handles chart tag lookups and tag destruction in an isolated environment
- Implements proper separation of concerns for better architectural design
]]

local ErrorHandler = require("core.utils.error_handler")
local GPSUtils = require("core.utils.gps_utils")
local PositionUtils = require("core.utils.position_utils")
local basic_helpers = require("core.utils.basic_helpers")

---@class TagRegistry
local TagRegistry = {}

-- Private functions and data
local function ensure_global_cache()
  _G.TagRegistry = _G.TagRegistry or {}
  _G.TagRegistry.surfaces = _G.TagRegistry.surfaces or {}
  _G.TagRegistry.recursion_guards = _G.TagRegistry.recursion_guards or {
    getting_chart_tag = false,
    removing_tag = false
  }
  return _G.TagRegistry
end

local function ensure_surface_cache(surface_index)
  local surface_idx = basic_helpers.normalize_index(surface_index)
  if not surface_idx then
    error("Invalid surface index: " .. tostring(surface_index))
  end
  local cache = ensure_global_cache()
  cache.surfaces[surface_idx] = cache.surfaces[surface_idx] or {}

  -- Always fetch chart tags to ensure fresh data
  local surface = game.surfaces[surface_idx]
  if surface then
    cache.surfaces[surface_idx].chart_tags = game.forces["player"].find_chart_tags(surface) or {}
  else
    cache.surfaces[surface_idx].chart_tags = {}
  end
  
  -- Always rebuild the GPS mapping
  cache.surfaces[surface_idx].chart_tags_mapped_by_gps = {}

  -- Build the GPS mapping
  local chart_tags = cache.surfaces[surface_idx].chart_tags
  local gps_map = cache.surfaces[surface_idx].chart_tags_mapped_by_gps
  
  -- Rebuild the GPS mapping
  for _, chart_tag in ipairs(chart_tags) do
    if chart_tag and chart_tag.valid and chart_tag.position and surface_idx then
      -- Ensure surface_idx is properly typed
      local surface_index_uint = tonumber(surface_idx) --[[@as uint]]
      -- Cast to number for gps_from_map_position function
      local surface_index_number = surface_index_uint --[[@as number]]
      local gps = GPSUtils.gps_from_map_position(chart_tag.position, surface_index_number)
      if gps and gps ~= "" then
        gps_map[gps] = chart_tag
      end
    end
  end

  return cache.surfaces[surface_idx]
end

-- Public API

--- Get a chart tag by GPS, bypassing circular dependencies
---@param gps string The GPS string to look up
---@return LuaCustomChartTag|nil The chart tag, or nil if not found
function TagRegistry.get_chart_tag_by_gps(gps)
  -- Add safety check to prevent recursion
  local cache = ensure_global_cache()
  if cache.recursion_guards.getting_chart_tag then
    ErrorHandler.debug_log("Recursion guard hit in get_chart_tag_by_gps", { gps = gps })
    return nil
  end
  
  -- Set recursion guard
  cache.recursion_guards.getting_chart_tag = true
  
  -- Function logic wrapped in pcall for safety
  local success, result = pcall(function()
    if not gps or gps == "" then return nil end
    
    -- Parse GPS to get surface index
    local surface_index = GPSUtils.get_surface_index_from_gps(gps)
    local surface = game.surfaces[surface_index]
    if not surface then return nil end
  
    -- Get chart tag from cache directly - avoid nested function calls that might recurse
    local surface_cache = ensure_surface_cache(surface_index)
    if not surface_cache then return nil end
    local match_chart_tag = surface_cache.chart_tags_mapped_by_gps[gps] or nil
    
    -- Validate chart tag
    if match_chart_tag and not match_chart_tag.valid then
      match_chart_tag = nil
      surface_cache.chart_tags_mapped_by_gps[gps] = nil -- Clear invalid reference
    end
    
    -- Don't do walkability check here to avoid potential circular dependencies
    -- This function should focus solely on retrieving the chart tag
    
    return match_chart_tag
  end)
  
  -- Always clear recursion guard, even on error
  cache.recursion_guards.getting_chart_tag = false
  
  if not success then
    ErrorHandler.debug_log("Error in get_chart_tag_by_gps", { error = result, gps = gps })
    return nil
  end
  
  return result
end

--- Remove a chart tag from the cache by GPS
---@param gps string The GPS string to remove
function TagRegistry.remove_chart_tag_by_gps(gps)
  if not gps or gps == "" then return end
  
  -- Get the chart tag
  local chart_tag = TagRegistry.get_chart_tag_by_gps(gps)
  
  -- Destroy the chart tag if it exists
  if chart_tag and chart_tag.valid then
    chart_tag.destroy()
  end
  
  -- Clear the cache for this surface
  local surface_index = GPSUtils.get_surface_index_from_gps(gps)
  if surface_index and surface_index > 0 then
    local cache = ensure_global_cache()
    cache.surfaces[surface_index] = nil
  end
end

--- Invalidate the chart tag cache for a surface
---@param surface_index number The surface index
function TagRegistry.invalidate_surface_chart_tags(surface_index)
  if not surface_index or surface_index < 1 then return end
  
  local cache = ensure_global_cache()
  cache.surfaces[surface_index] = nil
  
  ErrorHandler.debug_log("Invalidated chart tag cache for surface", {surface_index = surface_index})
end

--- Complete tag removal - handles both persistent storage and chart tag removal
--- This eliminates circular dependencies between Tag, Cache, and Lookups
---@param gps string The GPS string identifying the tag to remove
function TagRegistry.remove_tag_completely(gps)
  if not gps or gps == "" then return end
  
  -- Get recursion guard
  local cache = ensure_global_cache()
  if cache.recursion_guards.removing_tag then
    ErrorHandler.debug_log("Recursion guard hit in remove_tag_completely", { gps = gps })
    return
  end
  
  -- Set recursion guard
  cache.recursion_guards.removing_tag = true
  
  local success, error_msg = pcall(function()
    -- Step 1: Get surface index from GPS
    local surface_index = GPSUtils.get_surface_index_from_gps(gps)
    if not surface_index or surface_index < 1 then return end
    
    -- Log the operation
    ErrorHandler.debug_log("Starting complete tag removal", {gps = gps, surface_index = surface_index})
    
    -- Step 2: Remove chart tag from the game world
    local chart_tag = TagRegistry.get_chart_tag_by_gps(gps)
    if chart_tag and chart_tag.valid then
      chart_tag.destroy()
      ErrorHandler.debug_log("Chart tag destroyed in game world", {gps = gps})
    end
    
    -- Step 3: Remove from persistent storage directly
    -- Access storage table directly to avoid dependency on Cache module
    if storage and 
       storage.surfaces and 
       storage.surfaces[surface_index] and
       storage.surfaces[surface_index].tags then
      storage.surfaces[surface_index].tags[gps] = nil
      ErrorHandler.debug_log("Tag removed from persistent storage", {gps = gps})
    end
    
    -- Step 4: Clear registry cache for this surface
    TagRegistry.invalidate_surface_chart_tags(surface_index)
    
    -- Step 5: Direct remove from lookups cache to ensure consistency
    -- This is a direct operation to avoid circular dependencies
    if _G["Lookups"] and 
       _G["Lookups"].surfaces and 
       _G["Lookups"].surfaces[surface_index] and 
       _G["Lookups"].surfaces[surface_index].chart_tags_mapped_by_gps then
      _G["Lookups"].surfaces[surface_index].chart_tags_mapped_by_gps[gps] = nil
      ErrorHandler.debug_log("Tag removed from lookups cache", {gps = gps})
    end
    
    ErrorHandler.debug_log("Tag completely removed from system", {gps = gps, surface_index = surface_index})
  end)
  
  -- Always clear recursion guard
  cache.recursion_guards.removing_tag = false
  
  if not success then
    ErrorHandler.debug_log("Error in remove_tag_completely", { error = error_msg, gps = gps })
  end
end

--- Safe access to storage data without circular dependencies
---@param surface_index number
---@return table tags_table
local function get_storage_tags_safe(surface_index)
  if not storage or 
     not storage.surfaces or 
     not storage.surfaces[surface_index] or
     not storage.surfaces[surface_index].tags then
    return {}
  end
  
  return storage.surfaces[surface_index].tags
end

--- Invalidate the chart tag cache for a surface
---@param surface_index number
function TagRegistry.invalidate_surface_cache(surface_index)
  if not surface_index then
    return
  end
  
  local cache = ensure_global_cache()
  if cache.surfaces and cache.surfaces[surface_index] then
    cache.surfaces[surface_index] = nil
    ErrorHandler.debug_log("Invalidated chart tag cache for surface", {
      surface_index = surface_index
    })
  end
  
  -- Also invalidate Lookups cache if it exists
  if _G["Lookups"] and 
     _G["Lookups"].surfaces and 
     _G["Lookups"].surfaces[surface_index] then
    _G["Lookups"].surfaces[surface_index] = nil
  end
end

-- Initialize the registry
function TagRegistry.init()
  ensure_global_cache()
  return TagRegistry
end

return TagRegistry
