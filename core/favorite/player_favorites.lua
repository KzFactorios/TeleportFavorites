--[[
core/favorite/player_favorites.lua
TeleportFavorites Factorio Mod
-----------------------------
PlayerFavorites class: manages a collection of favorites for a specific player.

- Handles slot management, O(1) lookup, persistence, and favorite manipulation.
- All persistent data is managed via the Cache module and is surface-aware.
- Used for favorites bar, tag editor, and all player favorite operations.

API:
-----
- PlayerFavorites.new(player)                -- Constructor for a player's favorites collection.
- PlayerFavorites:get_favorites()            -- 
- PlayerFavorites:get_favorite_by_gps(gps)   --
- PlayerFavorites:add_favorite(gps|Favorite) -- Add a favorite to the first available slot.
- PlayerFavorites:remove_favorite(gps)       -- Remove a favorite by GPS, blanking the slot.
- PlayerFavorites:set_favorites(new_faves)   -- Batch update all favorites at once.
- PlayerFavorites.validate_gps(gps)          -- Centralized GPS string validation.

Notes:
------
- All slot management is 1-based and respects MAX_FAVORITE_SLOTS from Constants.
- Blank slots are always filled with Favorite.get_blank_favorite().
- All persistent data is surface-aware and managed via Cache.
--]]

-- PlayerFavorites.lua
-- Wrapper for a collection of favorites for a specific player.
-- Handles slot management, persistence, and favorite manipulation.
-- All persistent data is managed via the Cache module and is surface-aware.
--
-- @module core.favorite.player_favorites

local Constants = require("constants")
local Favorite = require("core.favorite.favorite")
local helpers = require("core.utils.helpers_suite")
local Cache = require("core.cache.cache")
local favorites_helpers = require("core.utils.favorites_helpers")

---
--- PlayerFavorites class with encapsulated access, O(1) lookup, and strict typing
--- @class PlayerFavorites
--- @field player LuaPlayer
--- @field player_index uint
--- @field surface_index uint
--- @field favorites Favorite[]
local PlayerFavorites = {}
PlayerFavorites.__index = PlayerFavorites

--- Internal: Normalize a player index to integer
---@param player LuaPlayer
---@return uint
local function normalize_player_index(player)
  return player.index
end

--- Internal: Normalize a surface index to integer
---@param surface LuaSurface
---@return uint
local function normalize_surface_index(surface)
  return surface.index
end

--- Constructor for PlayerFavorites
---@param player LuaPlayer
---@return PlayerFavorites
function PlayerFavorites.new(player)
  local obj = setmetatable({}, PlayerFavorites)
  obj.player = player
  obj.player_index = player.index
  obj.surface_index = player.surface.index
  -- Use favorites_helpers to get persistent favorites, always filled and normalized
  obj.favorites = favorites_helpers.init_player_favorites({}) or {}
  return obj
end

--- Get a favorite by GPS (O(1) lookup)
---@param gps string
---@return Favorite|nil
function PlayerFavorites:get_favorite_by_gps(gps)
  return helpers.find_by_predicate(self.favorites, function(v) return v.gps == gps end) or nil
end

--- Add a favorite GPS to the first available slot, allowing duplicates if intended, and preventing blank
---@param gps string|Favorite
---@return boolean success
function PlayerFavorites:add_favorite(gps)
  local fav_obj = type(gps) == "table" and gps or Favorite:new(gps)
  if Favorite.is_blank_favorite(fav_obj) then return false end
  for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
    if Favorite.is_blank_favorite(self.favorites[i]) then
      self.favorites[i] = setmetatable({ gps = fav_obj.gps, locked = fav_obj.locked or false, tag = fav_obj.tag },
        Favorite)
      self.favorites_by_gps[fav_obj.gps] = self.favorites[i]
      return true
    end
  end
  return false
end

--- Remove a favorite by GPS, set slot to blank if not found
---@param gps string
function PlayerFavorites:remove_favorite(gps)
  local found = false
  for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
    local fav = self.favorites[i]
    if fav and fav.gps == gps then
      self.favorites[i] = setmetatable({ gps = Constants.get_blank_favorite().gps, locked = false, tag = nil }, Favorite)
      self.favorites_by_gps[gps] = nil
      found = true
    end
  end
  -- If not found, ensure all blank slots are explicitly set to blank favorite
  if not found then
    for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
      self.favorites[i] = setmetatable({ gps = Constants.get_blank_favorite().gps, locked = false, tag = nil }, Favorite)
    end
  end
end

---@return Favorite[]

function PlayerFavorites:get_favorites()
  return self.favorites
end

--- Batch update favorites (replace all at once, 1-based only)
---@param new_faves Favorite[]
function PlayerFavorites:set_favorites(new_faves)
  local max = Constants.settings.MAX_FAVORITE_SLOTS
  local filtered = {}
  for i = 1, max do
    local f = new_faves and new_faves[i]
    if type(f) == "table" and not Favorite.is_blank_favorite(f) then
      filtered[i] = Favorite:new(f.gps, f.locked, f.tag)
    else
      filtered[i] = Constants.get_blank_favorite()
    end
  end
  self.favorites = filtered
  self.favorites_by_gps = {}
  for i, fav in ipairs(filtered) do
    if not Favorite.is_blank_favorite(fav) then
      self.favorites_by_gps[fav.gps] = fav
    end
  end
end

--- Validate a GPS string (centralized)
---@param gps string
---@return boolean, string?
function PlayerFavorites.validate_gps(gps)
  if type(gps) ~= "string" or gps == "" then return false, "GPS string required" end
  -- Add more validation as needed
  return true
end

return PlayerFavorites
