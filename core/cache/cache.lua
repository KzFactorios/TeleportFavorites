---@diagnostic disable: undefined-global

--[[
Cache.lua
TeleportFavorites Factorio Mod
-----------------------------
Persistent and runtime cache management for mod data, including player, surface, and tag storage.

- Provides helpers for safe cache access, mutation, and removal, with strict EmmyLua annotations.
- All persistent data is stored in the global table under  storage.cache,  storage.players, and  storage.surfaces.
- Runtime (non-persistent) lookup tables are managed via the Lookups module.
- Player and surface data are always initialized and normalized for safe multiplayer and multi-surface support.
- All access to persistent cache should use the Cache API; do not access  storage directly.

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
storage = {
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
local basic_helpers = require("core.utils.basic_helpers")
local favorites_helpers = require("core.utils.favorites_helpers")
local GPS = require("core.gps.gps")

--- Persistent and runtime cache management for TeleportFavorites mod.
---@class Cache
---@field lookups table<string, any> Lookup tables for chart tags and other runtime data.
local Cache = {}
Cache.__index = Cache

--- Lookup tables for chart tags and other runtime data.
Cache.lookups = Cache.lookups or Lookups.init()

--- Initialize the persistent cache table if not already present.
function Cache.init()
  if not storage or (storage and next(storage) == nil) then
    storage.players = {}
    storage.surfaces = {}
  end
  return storage
end

--- Retrieve a value from the persistent cache by key.
---@param key string
---@return any|nil
function Cache.get(key)
  if not key or key == "" then return nil end
  Cache.init()
  return storage[key]
end

--- Set a value in the persistent cache by key.
---@param key string
---@param value any
---@return any|nil The value set, or nil if storage is unavailable.
function Cache.set(key, value)
  if not key or key == "" then return nil end
  Cache.init(); storage.cache[key] = value
  return storage[key]
end

--- Remove a value from the persistent cache by key.
---@param key string
function Cache.remove(key)
  if not key or key == "" then return end
  Cache.init(); storage[key] = nil
end

--- Clear the entire persistent cache.
function Cache.clear()
  Cache.init()
  storage = {
    players = {},
    surfaces = {}
  }
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
  Cache.init()

  if not storage.players[player.index] then
    storage.players[player.index] = {}
  end
  local pdata = storage.players[player.index]
  if pdata.toggle_fav_bar_buttons == nil then
    pdata.toggle_fav_bar_buttons = true
  end
  pdata.render_mode = pdata.render_mode or (player and player.render_mode)
  pdata.tag_editor_data = {}
  pdata.drag_favorite_index = pdata.drag_favorite_index or -1

  pdata.surfaces = pdata.surfaces or {}
  pdata.surfaces[player.surface.index] = pdata.surfaces[player.surface.index] or { favorites = {} }

  favorites_helpers.init_player_favorites(pdata.surfaces[player.surface.index])

  return storage.players[player.index]
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
  Cache.init()
  storage.surfaces = storage.surfaces or {}
  storage.surfaces[surface_index] = storage.surfaces[surface_index] or {}
  local surface_data = storage.surfaces[surface_index]
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
  local idx = basic_helpers.normalize_surface_index(surface_index)
  if idx == 0 then return end
  local surface_data = init_surface_data(idx)
  if not surface_data or not surface_data.tags then return end
  surface_data.tags[gps] = nil
end

--- @param gps string
--- @return Tag|nil
function Cache.get_tag_by_gps(gps)
  if not gps or type(gps) ~= "string" or gps == "" then return nil end
  local surface_index = GPS.get_surface_index(gps) or 1
  local tag_cache = Cache.get_surface_tags(surface_index)
  -- find_by_predicate: returns a table of matches, or empty table
  local function find_by_predicate(tbl, pred)
    for k, v in pairs(tbl) do
      if pred(v, k) then return { v } end
    end
    return {}
  end
  local function table_count(tbl)
    local c = 0; for _ in pairs(tbl) do c = c + 1 end; return c
  end
  local found = find_by_predicate(tag_cache, function(v) return v.gps == gps end) or {}
  if table_count(found) > 0 then
    return found[1]
  end
  return nil
end

--- Get the favorites array for a player (persistent, surface-aware)
---@param player LuaPlayer
---@return Favorite[]
function Cache.get_player_favorites(player)
  local pdata = Cache.get_player_data(player) or {}
  local sidx = player.surface.index
  return pdata.surfaces and pdata.surfaces[sidx] and pdata.surfaces[sidx].favorites or {}
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

return Cache
