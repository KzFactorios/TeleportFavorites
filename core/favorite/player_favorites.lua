-- PlayerFavorites.lua
-- Wrapper for a collection of favorites for a specific player.
-- Handles slot management, persistence, and favorite manipulation.
-- All persistent data is managed via the Cache module and is surface-aware.
--
-- @module core.favorite.player_favorites

local Constants = require("constants")
local Favorite = require("core.favorite.favorite")
local Helpers = require("core.utils.helpers")

---
--- PlayerFavorites class with encapsulated access, O(1) lookup, and strict typing
--- @class PlayerFavorites
--- @field player LuaPlayer
--- @field player_index uint
--- @field surface_index uint
--- @field favorites Favorite[]
--- @field favorites_by_gps table<string, Favorite>
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
  local Cache = require("core.cache.cache")
  local obj = setmetatable({}, PlayerFavorites)
  obj.player = player
  obj.player_index = player.index
  obj.surface_index = player.surface.index
  obj.favorites = {}
  obj.favorites_by_gps = {}
  -- Use Cache to get persistent favorites
  local pfaves = Cache.get_player_favorites(player) or {}
  for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
    if not pfaves[i] or type(pfaves[i]) ~= "table" then
      ---@diagnostic disable-next-line: assign-type-mismatch
      pfaves[i] = Favorite.get_blank_favorite()
    end
    local fav = pfaves[i]
    if fav then
      fav.gps = fav.gps or ""
      fav.locked = fav.locked or false
      if fav.gps ~= "" then
        obj.favorites_by_gps[fav.gps] = fav
      end
    end
  end
  obj.favorites = pfaves
  return obj
end

--- Get the favorites array for this player
---@return Favorite[]
function PlayerFavorites:get_all()
  return self.favorites
end

--- Get a favorite by GPS (O(1) lookup)
---@param gps string
---@return Favorite|nil
function PlayerFavorites:get_favorite_by_gps(gps)
  return self.favorites_by_gps[gps]
end

--- Add a favorite GPS to the first available slot
---@param gps string
---@return boolean success
function PlayerFavorites:add_favorite(gps)
  for i, fav in ipairs(self.favorites) do
    if fav and fav.gps == "" then
      fav.gps = gps
      fav.locked = false
      self.favorites_by_gps[gps] = fav
      return true
    end
  end
  return false
end

--- Remove a favorite by GPS
---@param gps string
function PlayerFavorites:remove_favorite(gps)
  for i, fav in ipairs(self.favorites) do
    if fav and fav.gps == gps then
      ---@diagnostic disable-next-line: assign-type-mismatch
      self.favorites[i] = Favorite.get_blank_favorite()
      self.favorites_by_gps[gps] = nil
      return
    end
  end
end

--- Batch update favorites (replace all at once)
---@param new_faves Favorite[]
function PlayerFavorites:set_favorites(new_faves)
  self.favorites = new_faves
  return self.favorites
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
