---@diagnostic disable: undefined-global

--[[
Cache.lua
TeleportFavorites Factorio Mod
-----------------------------
Persistent and runtime cache management for mod data, including player, surface, and tag storage.

- Provides helpers for safe cache access, mutation, and removal, with strict EmmyLua annotations.
- All persistent data is stored in the global table under  storage.cache,  storage.players, and  storage.surfaces.
- Each player entry in storage.players[player_index] now includes a player_name field for the Factorio player name.
- Runtime (non-persistent) lookup tables are managed via the Lookups module.
- Player and surface data are always initialized and normalized for safe multiplayer and multi-surface support.
- All access to persistent cache should use the Cache API; do not access  storage directly.

Data Structure:
---------------
storage = {
  mod_version = string,
  ... other game-wide settings ...
  players = {
    [player_index] = {
      player_name = "FactorioPlayerName", -- ADDED: stores the player's name for easier debugging
      tag_editor_data = { ... },
      render_mode = string, -- ADDED: render mode for the player
      surfaces = {
        [surface_index] = {
          favorites = Favorite[], -- Array of Favorite objects for this surface
        },
        ...
      },
      ...
    },
    ...
  },
  surfaces = {
    [surface_index] = {
      tags = Tag[],
    },
    ...
  },
}
]]

local mod_version = require("core.utils.version")
local Lookups = require("core.cache.lookups")
local basic_helpers = require("core.utils.basic_helpers")
local GPS = require("core.gps.gps")
local Favorite = require("core.favorite.favorite")
local Constants = require("constants")


--- Persistent and runtime cache management for TeleportFavorites mod.
---@class Cache
---@field lookups table<string, any> Lookup tables for chart tags and other runtime data.
local Cache = {}
Cache.__index = Cache


-- Ensure storage is always a reference to global.storage for persistence
if rawget(_G, "global") == nil then _G.global = {} end
if not global.storage then global.storage = {} end
storage = global.storage


--- Lookup tables for chart tags and other runtime data.
Cache.lookups = Cache.lookups or Lookups.init()


--- Initialize the persistent cache table if not already present.
function Cache.init()
  if rawget(_G, "global") == nil then _G.global = {} end
  if not global.storage then global.storage = {} end
  storage = global.storage
  if not storage.players then storage.players = {} end
  if not storage.surfaces then storage.surfaces = {} end
  if not storage.mod_version or storage.mod_version ~= mod_version then
    storage.mod_version = mod_version
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

--- Clear the entire persistent cache.
function Cache.clear()
  Cache.init()
  if rawget(_G, "global") == nil then _G.global = {} end
  global.storage = { players = {}, surfaces = {} }
  storage = global.storage
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

--- At this point, we assume the player is already initialized and has a valid surface.
--- Initialize the player's favorites array, ensuring it has the correct structure. eg: min # favorites


--- Initialize and retrieve persistent player data for a given player.
---@param player LuaPlayer
---@return table Player data table (persistent)
local function init_player_data(player)
  if not player or not player.index then return {} end
  Cache.init()
  storage.players = storage.players or {}

  storage.players[player.index] = storage.players[player.index] or {}
  storage.players[player.index].surfaces = storage.players[player.index].surfaces or {}

  local player_data = storage.players[player.index]
  player_data.surfaces[player.surface.index] = player_data.surfaces[player.surface.index] or {}

  local function init_player_favorites(player)
    local pfaves = storage.players[player.index].surfaces[player.surface.index].favorites or {}

    for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
      if not pfaves[i] or type(pfaves[i]) ~= "table" then
        pfaves[i] = Favorite.get_blank_favorite()
      end
      pfaves[i].gps = pfaves[i].gps or ""
      pfaves[i].locked = pfaves[i].locked or false
    end

    storage.players[player.index].surfaces[player.surface.index].favorites = pfaves or {}
    return storage.players[player.index].surfaces[player.surface.index].favorites
  end
  
  player_data.surfaces[player.surface.index].favorites = init_player_favorites(player)

  player_data.player_name = player.name or "Unknown"
  player_data.render_mode = player_data.render_mode or player.render_mode
  player_data.tag_editor_data = player_data.tag_edor_data or {}

  return player_data
end


--- Get persistent player data for a given player.
---@param player LuaPlayer
---@return table --data table (persistent)
function Cache.get_player_data(player)
  if not player then return {} end
  return init_player_data(player)
end

---@param player LuaPlayer
---@return Favorite[] -- Returns the player's favorites array, or an empty table if not found.
function Cache.get_player_favorites(player)
  local player_data = Cache.get_player_data(player)
  local favorites = player_data.surfaces[player.surface.index].favorites or {}
  return favorites
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
  return sdata and sdata.tags or {}
end

--- Remove a tag from persistent storage by GPS string.
---@param gps string GPS string key for the tag.
function Cache.remove_stored_tag(gps)
  if not gps or type(gps) ~= "string" or gps == "" then return end

  local surface_index = GPS.get_surface_index(gps)
  if not surface_index or surface_index < 1 then return end

  local tag_cache = Cache.get_surface_tags(surface_index)
  if not tag_cache[gps] then return end

  tag_cache[gps] = nil
  -- Optionally, you can also remove the tag from the Lookups cache
  Lookups.remove_chart_tag_from_cache(gps)
end

--- @param gps string
--- @return Tag|nil
function Cache.get_tag_by_gps(gps)
  if not gps or gps == "" then return nil end
  local surface_index = GPS.get_surface_index(gps)
  if not surface_index or surface_index < 1 then return nil end

  local tag_cache = Cache.get_surface_tags(surface_index)
  return tag_cache[gps] or nil
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
