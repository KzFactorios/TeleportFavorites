local mod_version = require("core.utils.version")
local PlayerFavorites = require("core.favorte.player_favorites")
local Lookups = require("core/cache/lookups")

---@diagnostic disable: undefined-global
---@class Cache
local Cache = {}
Cache.__index = Cache

Cache.lookups = Cache.lookups or Lookups.init()

--- Initialize the cache if not already present
function Cache.init()
  if storage then
    storage.cache = storage.cache or {}
  end
end

--- Get a value from the cache by key
---@param key string
---@return any
function Cache.get(key)
  if not storage then return nil end
  if not storage.cache then Cache.init() end
  return storage.cache and storage.cache[key] or nil
end

--- Set a value in the cache by key
---@param key string
---@param value any
function Cache.set(key, value)
  if not storage then return end
  if not storage.cache then Cache.init() end
  if storage.cache then
    storage.cache[key] = value
    return storage.cache[key]
  end
  return nil
end

--- Remove a value from the cache by key
---@param key string
function Cache.remove(key)
  if not storage or not storage.cache then return end
  storage.cache[key] = nil
end

--- Clear the entire cache
function Cache.clear()
  if storage then
    storage.cache = {}
  end
end

--- Get the mod version from the cache, setting it if not present
---@return string
function Cache.get_mod_version()
  local val = tostring(Cache.get("mod_version"))
  if not val or val == "" then
    val = tostring(Cache.set("mod_version", mod_version))
  end
  return val
end

local function init_player_data(player)
  if not storage then return nil end
  if not storage.cache then Cache.init() end
  storage.players = storage.players or {}
  storage.players[player.index] = storage.players[player.index] or {}
  local player_data = storage.players[player.index]
  player_data.toggle_fav_bar_buttons = player_data.toggle_fav_bar_buttons or true
  player_data.render_mode = player_data.render_mode or player.render_mode
  player_data.surfaces = player_data.surfaces or {}
  player_data.surfaces[player.surface.index] = player_data.surfaces[player.surface.index] or {}
  local player_surface = player_data.surfaces[player.surface.index]
  player_surface.favorites = player_surface.favorites or PlayerFavorites.new(player)
  return player_data
end

function Cache.get_player_data(player)
  return init_player_data(player)
end

local function init_surface_data(surface_index)
  if not storage then return nil end
  if not storage.cache then Cache.init() end
  storage.surfaces = storage.surfaces or {}
  storage.surfaces[surface_index] = storage.surfaces[surface_index] or {}
  local surface_data = storage.surfaces[surface_index]
  surface_data.tags = surface_data.tags or {}
  return surface_data
end

function Cache.get_surface_data(surface_index)
  return init_surface_data(surface_index)
end

return Cache
