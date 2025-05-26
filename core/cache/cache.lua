--[[
Cache.lua
TeleportFavorites Factorio Mod
-----------------------------
Persistent and runtime cache management for mod data, including player, surface, and tag storage.

- Provides helpers for safe cache access, mutation, and removal, with strict EmmyLua annotations.
- All persistent data is stored in the global table under _G.storage.cache, _G.storage.players, and _G.storage.surfaces.
- Runtime (non-persistent) lookup tables are managed via the Lookups module.
- Player and surface data are always initialized and normalized for safe multiplayer and multi-surface support.
- All access to persistent cache should use the Cache API; do not access _G.storage directly.

API:
-----
- Cache.init()                        -- Initialize the persistent cache table if not present.
- Cache.get(key)                      -- Retrieve a value from the persistent cache by key.
- Cache.set(key, value)               -- Set a value in the persistent cache by key.
- Cache.remove(key)                   -- Remove a value from the persistent cache by key.
- Cache.clear()                       -- Clear the entire persistent cache and runtime chart_tag_cache.
- Cache.get_mod_version()             -- Get the mod version from the cache, if set.
- Cache.get_player_data(player)       -- Get persistent player data for a given player.
- Cache.get_surface_data(idx)         -- Get persistent surface data for a given surface index.
- Cache.get_surface_tags(idx)         -- Get the persistent tag table for a given surface index.
- Cache.remove_stored_tag(gps)        -- Remove a tag from persistent storage by GPS string.
- Cache.get_tag_by_gps(gps)           -- Get a tag by GPS string (persistent, surface-aware).
- Cache.get_player_favorites(player, surface) -- Get the favorites array for a player (persistent, surface-aware).
- Cache.get_tag_editor_data(player)   -- Get the tag editor data for a player (persistent, per-player).
- Cache.set_tag_editor_data(player, data) -- Set the tag editor data for a player (persistent, per-player).

Data Structure:
---------------
_G.storage = {
  cache = { ... },
  players = {
    [player_index] = {
      tag_editor_data = { ... },
      surfaces = {
        [surface_index] = {
          favorites = { ... },
        },
        ...
      },
      ...
    },
    ...
  },
  surfaces = {
    [surface_index] = {
      tags = { ... },
    },
    ...
  },
}
]]

local mod_version = require("core.utils.version")
local Lookups = require("core.cache.lookups")
local GPS = require("core.gps.gps")
local helpers = require("core.utils.Helpers")

-- Helper to require PlayerFavorites only when needed
local function get_player_favorites()
  return require("core.favorite.player_favorites")
end

---@diagnostic disable: undefined-global

-- Helper to safely convert to a positive integer index
local function safe_index(idx)
  idx = tonumber(idx)
  if not idx or idx < 1 then return 0 end
  return math.floor(idx)
end

--- Persistent and runtime cache management for TeleportFavorites mod.
---@class Cache
---@field lookups table<string, any> Lookup tables for chart tags and other runtime data.
local Cache = {}
Cache.__index = Cache

--- Lookup tables for chart tags and other runtime data.
Cache.lookups = Cache.lookups or Lookups.init()

--- Initialize the persistent cache table if not already present.
function Cache.init()
  _G.storage = _G.storage or {}
  _G.storage.cache = _G.storage.cache or {}
end

--- Retrieve a value from the persistent cache by key.
---@param key string
---@return any|nil
function Cache.get(key)
  if not key or key == "" then return nil end
  Cache.init()
  return _G.storage.cache[key]
end

--- Set a value in the persistent cache by key.
---@param key string
---@param value any
---@return any|nil The value set, or nil if storage is unavailable.
function Cache.set(key, value)
  if not key or key == "" then return nil end
  Cache.init(); _G.storage.cache[key] = value
  return _G.storage.cache[key]
end

--- Remove a value from the persistent cache by key.
---@param key string
function Cache.remove(key)
  if not key or key == "" then return end
  Cache.init(); _G.storage.cache[key] = nil
end

--- Clear the entire persistent cache.
function Cache.clear()
  Cache.init(); _G.storage.cache = {}
  if package.loaded["core.cache.lookups"] then
    package.loaded["core.cache.lookups"].clear_chart_tag_cache()
  end
end

--- Get the mod version from the cache, setting it if not present.
---@return string|nil
function Cache.get_mod_version()
  local val = Cache.get("mod_version")
  return (val and val ~= "") and tostring(val) or nil
end

--- Initialize and retrieve persistent player data for a given player.
---@param player LuaPlayer
---@return table Player data table (persistent)
local function init_player_data(player)
  if not _G.storage then return {} end
  if not _G.storage.cache then Cache.init() end
  _G.storage.players = _G.storage.players or {}
  local pidx = tonumber(helpers.normalize_player_index(player)) or 0
  if type(pidx) ~= "number" or pidx < 1 then return {} end
  local pdata = _G.storage.players[pidx] or {}
  pdata.toggle_fav_bar_buttons = pdata.toggle_fav_bar_buttons or true
  pdata.render_mode = pdata.render_mode or (player and player.render_mode)
  pdata.surfaces = pdata.surfaces or {}
  local sidx = tonumber(helpers.normalize_surface_index(player and player.surface)) or 1
  if type(sidx) ~= "number" or sidx < 1 then sidx = 1 end
  pdata.surfaces[sidx] = pdata.surfaces[sidx] or {favorites={}}
  _G.storage.players[pidx] = pdata
  return pdata
end

--- Get persistent player data for a given player.
---@param player LuaPlayer
---@return table Player data table (persistent)
function Cache.get_player_data(player)
  return init_player_data(player)
end

--- Initialize and retrieve persistent surface data for a given surface index.
---@param surface_index uint
---@return table Surface data table (persistent)
local function init_surface_data(surface_index)
  if not _G.storage then return {} end
  if not _G.storage.cache then Cache.init() end
  _G.storage.surfaces = _G.storage.surfaces or {}
  local idx = tonumber(surface_index) or 1
  if type(idx) ~= "number" or idx < 1 then idx = 1 end
  _G.storage.surfaces[idx] = _G.storage.surfaces[idx] or {}
  local surface_data = _G.storage.surfaces[idx]
  surface_data.tags = surface_data.tags or {}
  return surface_data
end

--- Get persistent surface data for a given surface index.
---@param surface_index uint
---@return table Surface data table (persistent)
function Cache.get_surface_data(surface_index)
  return init_surface_data(surface_index)
end

--- Get the persistent tag table for a given surface index.
---@param surface_index uint
---@return table<string, any> Table of tags indexed by GPS string.
function Cache.get_surface_tags(surface_index)
  local sdata = init_surface_data(surface_index)
  return sdata.tags or {}
end

--- Remove a tag from persistent storage by GPS string.
---@param gps string GPS string key for the tag.
function Cache.remove_stored_tag(gps)
  if not gps or type(gps) ~= "string" then return end
  local surface_index = GPS.get_surface_index(gps)
  if not surface_index then return end
  local idx = helpers.normalize_surface_index(surface_index)
  if idx == 0 then return end
  local surface_data = init_surface_data(idx)
  if not surface_data or not surface_data.tags then return end
  surface_data.tags[gps] = nil
end

--- @param gps string
--- @return Tag?
function Cache.get_tag_by_gps(gps)
  if not gps or type(gps) ~= "string" or gps == "" then return nil end
  local surface_index = GPS.get_surface_index(gps)
  if type(surface_index) ~= "number" or surface_index < 1 then
    surface_index = 1 --[[@as uint]] -- ensure this is always a positive unsigned integer (uint)
  end
  local tag_cache = Cache.get_surface_tags(surface_index)
  local found = helpers.find_by_predicate(tag_cache, function(v) return v.gps == gps end) or {}
  if helpers.table_count(found) > 0 then
    return found[1]
  end
  return nil
end

--- Get the favorites array for a player (persistent, surface-aware)
---@param player LuaPlayer
---@param surface LuaSurface|nil
---@return Favorite[]
function Cache.get_player_favorites(player, surface)
  local pdata = Cache.get_player_data(player) or {}
  local sidx = surface and surface.index or player.surface.index
  if pdata.surfaces and pdata.surfaces[sidx] and pdata.surfaces[sidx].favorites then
    return pdata.surfaces[sidx].favorites
  end
  return {}
end

--- Get the tag editor data for a player (persistent, per-player)
---@param player LuaPlayer
---@return table|nil
function Cache.get_tag_editor_data(player)
  local pdata = Cache.get_player_data(player)
  return pdata and pdata.tag_editor_data or nil
end

--- Set the tag editor data for a player (persistent, per-player)
---@param player LuaPlayer
---@param data table|nil
function Cache.set_tag_editor_data(player, data)
  local pdata = Cache.get_player_data(player)
  pdata.tag_editor_data = data
end

--- Normalize a player index to integer
---@param player LuaPlayer|number|string
---@return integer
local function normalize_player_index(player)
  if type(player) == "table" and player.index then return player.index end
  return math.floor(tonumber(player) or 0)
end

--- Normalize a surface index to integer
---@param surface LuaSurface|number|string
---@return integer
local function normalize_surface_index(surface)
  if type(surface) == "table" and surface.index then return surface.index end
  return math.floor(tonumber(surface) or 0)
end

return Cache
