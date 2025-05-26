local Helpers = require("core.utils.helpers")
local gps_helpers = require("core.utils.gps_helpers")

---@diagnostic disable: undefined-global
---@class Lookups
-- Handles the non-persistent in-game data cache for runtime lookups.
-- The cache is stored in the non-persistent global table under the key 'tf_cache'.

local Lookups = {}
Lookups.__index = Lookups

local CACHE_KEY = "Lookups"

local function normalize_surface_index(surface_index)
  local idx = tonumber(surface_index)
  if not idx or idx < 1 then return 1 end
  return math.floor(idx)
end

function Lookups.ensure_surface_cache(surface_index)
  local cache = Lookups.ensure_cache()
  local surface_data = cache.surfaces or {}
  surface_data[surface_index] = surface_data[surface_index] or {}
  surface_data[surface_index].chart_tags = surface_data[surface_index].chart_tags or {}
  surface_data[surface_index].tag_editor_positions = surface_data[surface_index].tag_editor_positions or {}
  return surface_data[surface_index]
end

--- Ensure the cache table exists in global (non-persistent)
local function ensure_cache()
  _G[CACHE_KEY] = _G[CACHE_KEY] or {}
  local cache = _G[CACHE_KEY]
  cache.surfaces = cache.surfaces or {}
  return cache
end

Lookups.ensure_cache = ensure_cache

--- Get a value from the cache
function Lookups.get(key)
  if not key or key == "" then return nil end
  local cache = ensure_cache()
  return cache[key]
end

--- Set a value in the cache
function Lookups.set(key, value)
  if not key or key == "" then return end
  local cache = ensure_cache()
  cache[key] = value
end

--- Remove a value from the cache
function Lookups.remove(key)
  if not key or key == "" then return end
  local cache = ensure_cache()
  cache[key] = nil
end

--- Clear the entire cache
function Lookups.clear()
  _G[CACHE_KEY] = {}
end

--- Get or initialize the chart_tag_cache for a surface
function Lookups.get_chart_tag_cache(surface_index)
  local idx = normalize_surface_index(surface_index)
  local cache = ensure_cache()
  cache.surfaces[idx] = cache.surfaces[idx] or {}
  local surface = cache.surfaces[idx]
  -- Always store as a numerically indexed array
  if not surface.chart_tag_cache or type(surface.chart_tag_cache) ~= "table" then
    surface.chart_tag_cache = {}
  end
  -- Rebuild from game if empty
  ---@diagnostic disable-next-line
  if Helpers.table_count(surface.chart_tag_cache) == 0 and game and game.forces and game.forces["player"] and game.surfaces and game.surfaces[idx] then
    surface.chart_tag_cache = game.forces["player"]:find_chart_tags(game.surfaces[idx])
  end
  -- Always rebuild O(1) lookup map by gps after cache is cleared or rebuilt
  surface.chart_tag_cache_by_gps = {}
  for _, chart_tag in ipairs(surface.chart_tag_cache) do
    local gps = gps_helpers.gps_from_map_position(chart_tag.position, idx)
    surface.chart_tag_cache_by_gps[gps] = chart_tag
  end
  return surface.chart_tag_cache
end

--- Static method to fetch a LuaCustomChartTag by gps (O(1) lookup)
---@param gps string
---@return LuaCustomChartTag|nil
function Lookups.get_chart_tag_by_gps(gps)
  if not gps or type(gps) ~= "string" or gps == "" then return nil end
  local surface_index = gps_helpers.get_surface_index(gps) or 1
  local idx = normalize_surface_index(surface_index)
  local cache = ensure_cache()
  local surface = cache.surfaces[idx]
  if not surface or not surface.chart_tag_cache_by_gps then
    Lookups.get_chart_tag_cache(idx) -- ensure map is built
    surface = cache.surfaces[idx]
  end
  if surface and type(surface.chart_tag_cache_by_gps) == "table" then
    return surface.chart_tag_cache_by_gps[gps]
  end
  return nil
end

--- Set the tag editor position for a player on a surface
function Lookups.set_tag_editor_position(player, map_position)
  local tag_editor_positions = Lookups.get_tag_editor_positions(player.surface.index)
  tag_editor_positions[player.index] = map_position
end

--- Get the tag editor position for a player on a surface
function Lookups.get_tag_editor_position(player)
  local tag_editor_positions = Lookups.get_tag_editor_positions(player.surface.index)
  return tag_editor_positions[player.index]
end

--- Clear the tag editor position for a player on a surface
function Lookups.clear_tag_editor_position(player)
  local tag_editor_positions = Lookups.get_tag_editor_positions(player.surface.index)
  tag_editor_positions[player.index] = nil
end

--- Get or initialize the tag_editor_positions for a surface
function Lookups.get_tag_editor_positions(surface_index)
  local idx = normalize_surface_index(surface_index)
  local cache = ensure_cache()
  cache.surfaces[idx] = cache.surfaces[idx] or {}
  local surface = cache.surfaces[idx]
  surface.tag_editor_positions = surface.tag_editor_positions or {}
  return surface.tag_editor_positions
end

--- Clear the chart_tag_cache for a given surface (or all surfaces if no index given)
function Lookups.clear_chart_tag_cache(surface_index)
  local cache = ensure_cache()
  if surface_index then
    local idx = normalize_surface_index(surface_index)
    if cache.surfaces[idx] then
      cache.surfaces[idx].chart_tag_cache = {}
      cache.surfaces[idx].chart_tag_cache_by_gps = {}
    end
  else
    for _, surface in pairs(cache.surfaces) do
      surface.chart_tag_cache = {}
      surface.chart_tag_cache_by_gps = {}
    end
  end
end

--- Initialize the Lookups cache (for tests or mod init)
function Lookups.init()
  _G[CACHE_KEY] = {}
  local cache = _G[CACHE_KEY]
  cache.surfaces = {}
  return cache
end

return Lookups

--[[
tf_cache = {
    surfaces[surface_index] = {
        chart_tag_cache = {
            an array of LuaCustomChartTag objects indexed by gps (converted from the position and the surface_index)
        },
        tag_editor_positions = {
            [player_index] = gps
        }
    }
}
]]
