-- PlayerFavorites.lua
-- Wrapper for a collection of favorites for a specific player.
-- Handles slot management, persistence, and favorite manipulation.
-- All persistent data is managed via the Cache module and is surface-aware.
--
-- @module core.favorite.player_favorites

local Constants = require("constants")
local Favorite = require("core.favorite.favorite")
local Helpers = require("core.utils.helpers")
local Cache = require("core.cache.cache")

---
--- Collection of favorite locations for a specific player.
--- Handles slot management, persistence, and favorite manipulation.
--- @class PlayerFavorites
--- @field player LuaPlayer The player this collection belongs to
--- @field player_index uint The index of the player
--- @field surface_index uint The index of the player's current surface
--- @field favorites table<number, Favorite> Array of Favorite objects for this player (indexed by slot)
local PlayerFavorites = {}
PlayerFavorites.__index = PlayerFavorites

local blank_favorite = Favorite.get_blank_favorite

--- Constructor for PlayerFavorites
---@param player LuaPlayer The player to create favorites for
---@return PlayerFavorites
function PlayerFavorites.new(player)
  local obj = setmetatable({}, PlayerFavorites)
  obj.player = player
  obj.player_index = player.index
  obj.surface_index = player.surface.index
  obj.favorites = {}
  -- Ensure persistent storage exists using Cache
  Cache.init()
  local pdata = Cache.get_player_data(player) or {}
  local pfaves = pdata.surfaces[player.surface.index].favorites or {}
  -- Initialize slots if empty
  for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
    if not pfaves[i] or type(pfaves[i]) ~= "table" then
      pfaves[i] = Favorite.get_blank_favorite()
    else
      pfaves[i].gps = pfaves[i].gps or ""
      pfaves[i].locked = pfaves[i].locked or false
    end
  end
  obj.favorites = pfaves
  return obj
end

--- Get the favorites array for a player (static helper)
---@param player LuaPlayer
---@return Favorite[]
function PlayerFavorites.get_player_favorites(player)
  if not player then return {} end
  local pdata = Cache.get_player_data(player) or {}
  local pfaves = pdata.surfaces[player.surface.index].favorites or {}
  return pfaves
end

--- Add a favorite GPS to the first available slot
---@param player LuaPlayer
---@param gps string GPS string to add
---@return boolean success True if added, false if no open slot
function PlayerFavorites.add_favorite(player, gps)
  if not player then return false end
  local tag = Cache.get_surface_tags(player.surface.index) 
  local player_favorites = PlayerFavorites.get_player_favorites(player)
  for i, fav in ipairs(player_favorites) do
    if fav and fav.gps == "" then
      fav.gps = gps
      fav.locked = false
      tag.add_faved_by_player(player.index)
      return true
    end
  end
  return false -- No open slot
end

--- Remove a favorite by GPS
---@param player LuaPlayer
---@param gps string GPS string to remove
function PlayerFavorites.remove_favorite(player, gps)
  -- find the tag with matching gps
  local tag = Cache.get_tag_by_gps(gps)
  if not tag then return end

  -- reset any favorites for the current player
  local player_favorites = PlayerFavorites.get_player_favorites(player)
  for i, fav in ipairs(player_favorites) do
    if fav and fav.gps == gps then
      ---@diagnostic disable-next-line: assign-type-mismatch
      player_favorites[i] = Favorite.get_blank_favorite()
      return
    end
  end

  -- removed player index from faved_by_players
  Helpers.remove_first(tag.faved_by_players, player.index)
end

--- Swap two favorite slots by index
---@param idx1 number First slot index
---@param idx2 number Second slot index
function PlayerFavorites:swap_slots(idx1, idx2)
  self.favorites[idx1], self.favorites[idx2] = self.favorites[idx2], self.favorites[idx1]
end

--- Get the list of all favorite GPS strings
---@return string[]
function PlayerFavorites:get_all_gps()
  local list = {}
  for i, fav in ipairs(self.favorites) do
    table.insert(list, fav.gps)
  end
  return list
end

--- Cascade favorites up from a given index (pushes elements up, must be room, locked slots cannot be moved)
---@param from_idx number Index to start cascading from (1-based)
---@return boolean success True if cascade succeeded, false otherwise
function PlayerFavorites:cascade_slots_up(from_idx)
  local max_slots = Constants.settings.MAX_FAVORITE_SLOTS
  -- Find the first empty slot above from_idx
  local empty_idx = nil
  for i = from_idx - 1, 1, -1 do
    if self.favorites[i] and self.favorites[i].gps == "" then
      empty_idx = i
      break
    end
  end
  if not empty_idx then return false end -- No room to cascade up
  -- Cascade up, skipping locked slots
  for i = empty_idx, from_idx - 1 do
    if not self.favorites[i + 1] or self.favorites[i + 1].locked then
      return false -- Cannot move locked slot
    end
    if not self.favorites[i] then
      ---@diagnostic disable-next-line: assign-type-mismatch
      self.favorites[i] = Favorite.get_blank_favorite()
    end
    self.favorites[i].gps = self.favorites[i + 1].gps
    self.favorites[i].locked = self.favorites[i + 1].locked
    -- Clear the slot we just copied from
    if i + 1 == from_idx then
      ---@diagnostic disable-next-line: assign-type-mismatch
      self.favorites[i + 1] = Favorite.get_blank_favorite()
    end
  end
  return true
end

--- Cascade favorites down from a given index (pushes elements down, must be room, locked slots cannot be moved)
---@param from_idx number Index to start cascading from (1-based)
---@return boolean success True if cascade succeeded, false otherwise
function PlayerFavorites:cascade_slots_down(from_idx)
  local max_slots = Constants.settings.MAX_FAVORITE_SLOTS
  -- Find the first empty slot below from_idx
  local empty_idx = nil
  for i = from_idx + 1, max_slots do
    if self.favorites[i] and self.favorites[i].gps == "" then
      empty_idx = i
      break
    end
  end
  if not empty_idx then return false end -- No room to cascade down
  -- Cascade down, skipping locked slots
  for i = empty_idx, from_idx + 1, -1 do
    if not self.favorites[i - 1] or self.favorites[i - 1].locked then
      return false -- Cannot move locked slot
    end
    if not self.favorites[i] then
      ---@diagnostic disable-next-line: assign-type-mismatch
      self.favorites[i] = Favorite.get_blank_favorite()
    end
    self.favorites[i].gps = self.favorites[i - 1].gps
    self.favorites[i].locked = self.favorites[i - 1].locked
    -- Clear the slot we just copied from
    if i - 1 == from_idx then
      ---@diagnostic disable-next-line: assign-type-mismatch
      self.favorites[i - 1] = Favorite.get_blank_favorite()
    end
  end
  return true
end

return PlayerFavorites
