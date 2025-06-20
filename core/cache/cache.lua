---@diagnostic disable: undefined-global

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
local FavoriteUtils = require("core.favorite.favorite")
local Constants = require("constants")
local GPSUtils = require("core.utils.gps_utils")
local Lookups = require("core.cache.lookups")
local PositionUtils = require("core.utils.position_utils")
local ErrorHandler = require("core.utils.error_handler")

-- Lazy-loaded Lookups module to avoid circular dependency
-- Observer Pattern Integration
local function notify_observers_safe(event_type, data)
  -- Safe notification that handles module load order
  local success, gui_observer = pcall(require, "core.pattern.gui_observer")
  if success and gui_observer.GuiEventBus then
    gui_observer.GuiEventBus.notify(event_type, data)
  end
end

--- Persistent and runtime cache management for TeleportFavorites mod.
---@class Cache
---@field Lookups table<string, any> Lookup tables for chart tags and other runtime data.
local Cache = {}
Cache.__index = Cache
--- Lookup tables for chart tags and other runtime data.
Cache.Lookups = nil


-- Ensure storage is always available for persistence (Factorio 2.0+)
if not storage then
  error("Storage table not available - this mod requires Factorio 2.0+")
end

--- Initialize the persistent cache table if not already present.
function Cache.init()
  if not storage then
    error("Storage table not available - this mod requires Factorio 2.0+")
  end
  storage.players = storage.players or {}
  storage.surfaces = storage.surfaces or {}  if not storage.mod_version or storage.mod_version ~= mod_version then
    storage.mod_version = mod_version
  end
    -- Initialize lookups cache properly
  Lookups.init()
  Cache.Lookups = Lookups
  
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
function Cache.set(key, value)
  if not key or key == "" then return end
  Cache.init()
  storage[key] = value
end

--- Clear the entire persistent cache.
function Cache.clear()
  if not storage then
    error("Storage table not available - cannot clear cache")
  end

  -- Clear all data while preserving storage table reference
  for k in pairs(storage) do
    storage[k] = nil
  end

  -- Reinitialize with clean structure
  storage.players = {}
  storage.surfaces = {}
  storage.mod_version = mod_version
  -- Clear non-persistent lookup cache if available
  if package.loaded["core.cache.lookups"] then
    local lookups_module = package.loaded["core.cache.lookups"]
    if lookups_module.clear_all_caches then
      lookups_module.clear_all_caches()
    end
  end

  -- Notify observers of cache refresh
  notify_observers_safe("cache_updated", {
    type = "cache_cleared",
    timestamp = game and game.tick or 0
  })
end

--- Get the mod version from the cache, setting it if not present.
---@return string|nil
function Cache.get_mod_version()
  local val = Cache.get("mod_version")
  return (val and val ~= "") and tostring(val) or nil
end

-- At this point, we assume the player is already initialized and has a valid surface.
-- Initialize the player's favorites array, ensuring it has the correct structure. eg: min # favorites


--- Initialize and retrieve persistent player data for a given player.
---@param player LuaPlayer
---@return table Player data table (persistent)
local function ensure_player_cache(player)
  if not player or not player.valid or not player.index then return {} end
  Cache.init()
  storage.players = storage.players or {}
  storage.players[player.index] = storage.players[player.index] or {}
  return storage.players[player.index]
end

local function init_player_data(player)
  if not player or not player.index then return {} end
  Cache.init()
  storage.players = storage.players or {}

  storage.players[player.index] = storage.players[player.index] or {}
  storage.players[player.index].surfaces = storage.players[player.index].surfaces or {}

  local player_data = storage.players[player.index]
  player_data.surfaces[player.surface.index] = player_data.surfaces[player.surface.index] or {}

  local function init_player_favorites(player)
    local pfaves = storage.players[player.index].surfaces[player.surface.index].favorites or {}    for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
      if not pfaves[i] or type(pfaves[i]) ~= "table" then
        pfaves[i] = FavoriteUtils.get_blank_favorite()
      end
      -- Don't override GPS if it's already set - preserve BLANK_GPS value
      pfaves[i].gps = pfaves[i].gps or Constants.settings.BLANK_GPS
      pfaves[i].locked = pfaves[i].locked or false
    end

    storage.players[player.index].surfaces[player.surface.index].favorites = pfaves or {}
    return storage.players[player.index].surfaces[player.surface.index].favorites
  end

  player_data.surfaces[player.surface.index].favorites = init_player_favorites(player)
  player_data.player_name = player.name or "Unknown"
  player_data.render_mode = player_data.render_mode or player.render_mode
  player_data.tag_editor_data = player_data.tag_editor_data or Cache.create_tag_editor_data()
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
-- Returns the player's favorites array, or an empty table if not found.
---@return table[]
function Cache.get_player_favorites(player)
  local player_data = Cache.get_player_data(player)
  local favorites = player_data.surfaces[player.surface.index].favorites or {}
  return favorites
end

---@param player LuaPlayer
---@param gps string
---@return table|nil
function Cache.is_player_favorite(player, gps)
  local player_faves = Cache.get_player_favorites(player)
  local player_favorite = nil
  for k, v in pairs(player_faves) do
    if v.gps == gps then
      player_favorite = v
      break
    end
  end
  return player_favorite
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

  local surface_index = GPSUtils.get_surface_index_from_gps(gps)
  if not surface_index or surface_index < 1 then return end
  local safe_surface_index = tonumber(surface_index) and math.floor(surface_index) or nil
  if not safe_surface_index or safe_surface_index < 1 then return end
  local uint_surface_index = safe_surface_index --[[@as uint]]  local tag_cache = Cache.get_surface_tags(uint_surface_index)
  if not tag_cache[gps] then return end
  tag_cache[gps] = nil
  
  -- Remove the tag from the Lookups cache as well
  Cache.init() -- Ensure Lookups is initialized
  ---@diagnostic disable-next-line: undefined-field, need-check-nil
  Cache.Lookups.remove_chart_tag_from_cache_by_gps(gps)
end

--- @param gps string
--- @return Tag|nil
function Cache.get_tag_by_gps(gps)
  if not gps or gps == "" then return nil end
  local surface_index = GPSUtils.get_surface_index_from_gps(gps)
  if not surface_index or surface_index < 1 then return nil end
  local surface = game.surfaces[surface_index]
  if not surface then return nil end

  local tag_cache = Cache.get_surface_tags(surface_index --[[@as uint]])
  local match_tag = tag_cache[gps] or nil
  
  -- Return the tag if it exists and is valid, otherwise return nil
  local is_valid_location = match_tag and match_tag.chart_tag and match_tag.chart_tag.valid and 
    PositionUtils.is_walkable_position(surface, match_tag.chart_tag.position) or false

  if is_valid_location and match_tag then
    return match_tag
  end
  
  return nil
end

--- Get the tag editor data for a player (persistent, per-player)
---@param player LuaPlayer
---@return table
function Cache.get_tag_editor_data(player)
  return Cache.get_player_data(player).tag_editor_data
end

--- Set the tag editor data for a player (persistent, per-player)
---@param player LuaPlayer
---@param data table|nil
---@return table
function Cache.set_tag_editor_data(player, data)
  if not data then data = {} end
  local pdata = Cache.get_player_data(player)

  -- If data is empty table, clear all tag_editor_data
  local is_empty = true
  for _ in pairs(data) do
    is_empty = false
    break
  end

  if is_empty then
    pdata.tag_editor_data = Cache.create_tag_editor_data()
  else
    for k, v in pairs(data) do
      pdata.tag_editor_data[k] = v
    end
  end

  return pdata.tag_editor_data
end

--- Create a new tag_editor_data structure with default values
--- This centralized factory method eliminates duplication across the codebase
---@param options table|nil Optional override values for specific fields
---@return table tag_editor_data structure with all required fields
function Cache.create_tag_editor_data(options)
  local defaults = {
    gps = "",
    move_gps = "",
    locked = false,
    is_favorite = false,
    icon = "",
    text = "",
    tag = {}, -- do not use nil
    chart_tag = {}, -- do not use nil
    error_message = "",
    search_radius = 1,
    -- Delete confirmation state
    delete_mode = false,
    pending_delete = false
  }

  if not options or type(options) ~= "table" then
    return defaults
  end

  -- Merge options with defaults, allowing partial overrides
  local result = {}
  for key, default_value in pairs(defaults) do
    result[key] = options[key] ~= nil and options[key] or default_value
  end

  return result
end

-- Set the pending delete flag in tag_editor_data
function Cache.set_tag_editor_delete_mode(player, is_delete_mode)
  if not player or not player.valid then return end
  
  local tag_data = Cache.get_tag_editor_data(player)
  tag_data.delete_mode = is_delete_mode == true
  
  -- Ensure we keep the tag_editor_data updated
  Cache.set_tag_editor_data(player, tag_data)
end

-- Check if the tag editor is in delete mode
function Cache.is_tag_editor_delete_mode(player)
  if not player or not player.valid then return false end
  
  local tag_data = Cache.get_tag_editor_data(player)
  return tag_data.delete_mode == true
end

-- Reset the delete mode flag in tag_editor_data
function Cache.reset_tag_editor_delete_mode(player)
  if not player or not player.valid then return end
  
  local tag_data = Cache.get_tag_editor_data(player)
  tag_data.delete_mode = false
  
  -- Ensure we keep the tag_editor_data updated
  Cache.set_tag_editor_data(player, tag_data)
end

--- Generic sanitizer for objects to be stored in persistent storage
---@param obj table
---@param exclude_fields table<string, boolean>|nil -- set of field names to exclude
---@return table sanitized_obj
function Cache.sanitize_for_storage(obj, exclude_fields)
  if type(obj) ~= "table" then return {} end
  local sanitized = {}
  exclude_fields = exclude_fields or {}
  for k, v in pairs(obj) do
    if not exclude_fields[k] and type(v) ~= "userdata" then
      sanitized[k] = v
    end
  end
  return sanitized
end

return Cache
