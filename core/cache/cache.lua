--[[
  Cache.lua
  TeleportFavorites Factorio Mod
  -----------------------------
  Persistent and runtime cache management for mod data, including player, surface, and tag storage.
  Provides helpers for safe cache access, mutation, and removal, with strict EmmyLua annotations.

  @module Cache
  @author Gemini
  @license MIT
  @see core.cache.lookups
  @see core.favorite.player_favorites
  @see core.gps.gps
]]

local mod_version = require("core.utils.version")
local PlayerFavorites = require("core.favorite.player_favorites")
local Lookups = require("core.cache.lookups")
local GPS = require("core.gps.gps")

---@diagnostic disable: undefined-global

--- Persistent and runtime cache management for TeleportFavorites mod.
---@class Cache
---@field lookups table<string, any> Lookup tables for chart tags and other runtime data.
local Cache = {}
Cache.__index = Cache

--- Lookup tables for chart tags and other runtime data.
Cache.lookups = Cache.lookups or Lookups.init()

--- Initialize the persistent cache table if not already present.
function Cache.init()
  if storage then
    storage.cache = storage.cache or {}
  end
end

--- Retrieve a value from the persistent cache by key.
---@param key string
---@return any|nil
function Cache.get(key)
  if not storage then return nil end
  if not storage.cache then Cache.init() end
  return storage.cache and storage.cache[key] or nil
end

--- Set a value in the persistent cache by key.
---@param key string
---@param value any
---@return any|nil The value set, or nil if storage is unavailable.
function Cache.set(key, value)
  if not storage then return end
  if not storage.cache then Cache.init() end
  if storage.cache then
    storage.cache[key] = value
    return storage.cache[key]
  end
  return nil
end

--- Remove a value from the persistent cache by key.
---@param key string
function Cache.remove(key)
  if not storage or not storage.cache then return end
  storage.cache[key] = nil
end

--- Clear the entire persistent cache.
function Cache.clear()
  if storage then
    storage.cache = {}
  end
end

--- Get the mod version from the cache, setting it if not present.
---@return string
function Cache.get_mod_version()
  local val = tostring(Cache.get("mod_version"))
  if not val or val == "" then
    val = tostring(Cache.set("mod_version", mod_version))
  end
  return val
end

--- Initialize and retrieve persistent player data for a given player.
---@param player LuaPlayer
---@return table Player data table (persistent)
local function init_player_data(player)
  if not storage then return {} end
  if not storage.cache then Cache.init() end
  storage.players = storage.players or {}
  local pidx = safe_index(player.index)
  storage.players[pidx] = storage.players[pidx] or {}
  local player_data = storage.players[pidx]
  player_data.toggle_fav_bar_buttons = player_data.toggle_fav_bar_buttons or true
  player_data.render_mode = player_data.render_mode or player.render_mode
  player_data.surfaces = player_data.surfaces or {}
  local sidx = safe_index(player.surface.index)
  player_data.surfaces[sidx] = player_data.surfaces[sidx] or {}
  local player_surface = player_data.surfaces[sidx]
  player_surface.favorites = player_surface.favorites or PlayerFavorites.new(player)
  return player_data
end

--- Get persistent player data for a given player.
---@param player LuaPlayer
---@return table Player data table (persistent)
function Cache.get_player_data(player)
  return init_player_data(player)
end

--- Initialize and retrieve persistent surface data for a given surface index.
---@param surface_index number
---@return table Surface data table (persistent)
local function init_surface_data(surface_index)
  if not storage then return {} end
  if not storage.cache then Cache.init() end
  storage.surfaces = storage.surfaces or {}
  local idx = safe_index(surface_index)
  storage.surfaces[idx] = storage.surfaces[idx] or {}
  local surface_data = storage.surfaces[idx]
  surface_data.tags = surface_data.tags or {}
  return surface_data
end

--- Get persistent surface data for a given surface index.
---@param surface_index number
---@return table Surface data table (persistent)
function Cache.get_surface_data(surface_index)
  return init_surface_data(surface_index)
end

--- Get the persistent tag table for a given surface index.
---@param surface_index number
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
  local idx = safe_index(surface_index)
  if idx == 0 then return end
  local surface_data = init_surface_data(idx)
  if not surface_data or not surface_data.tags then return end
  surface_data.tags[gps] = nil
end

return Cache
