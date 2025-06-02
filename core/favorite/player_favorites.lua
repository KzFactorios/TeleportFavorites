--[[
core/favorite/player_favorites.lua
TeleportFavorites Factorio Mod
-----------------------------
PlayerFavorites class: manages a collection of favorites for a specific player.

- Handles slot management, O(1) lookup, persistence, and favorite manipulation.
- All persistent data is managed via the Cache module and is surface-aware.
- Used for favorites bar, tag editor, and all player favorite operations.

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

local Constants = require("constants")
local Favorite = require("core.favorite.favorite")
local Helpers = require("core.utils.helpers_suite")
local basic_helpers = require("core.utils.basic_helpers")
local gps_helpers = require("core.utils.gps_helpers")
local Cache = require("core.cache.cache")


--- PlayerFavorites class with encapsulated access, O(1) lookup, and strict typing
--- @class PlayerFavorites
--- @field player LuaPlayer
--- @field player_index uint
--- @field surface_index uint
--- @field favorites Favorite[]
local PlayerFavorites = {}
PlayerFavorites.__index = PlayerFavorites


--- Get a favorite by GPS (O(1) lookup)
---@param gps string
---@return Favorite|nil
function PlayerFavorites:get_favorite_by_gps(gps)
  return Helpers.find_by_predicate(self.favorites, function(v) return v.gps == gps end) or nil
end

--- Add a favorite GPS to the first available slot. Update matched Tag and storage
---@param gps string
---@return Favorite|nil
function PlayerFavorites:add_favorite(gps)
  if not gps or type(gps) ~= "string" or gps == "" then return nil end

  local existing_fave = self:get_favorite_by_gps(gps)
  if existing_fave then return existing_fave end

  local slot_idx = 0
  local existing_tag = Cache.get_tag_by_gps(gps)

  -- find the first available index
  for _i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
    if Favorite.is_blank_favorite(self.favorites[_i]) then
      slot_idx = _i
      break
    end
  end

  -- if no blank slot found, return nil
  -- this means the favorites are full and we cannot add a new one
  if slot_idx == 0 then return nil end

  local new_favorite = Favorite.new(gps, false, existing_tag)
  if not new_favorite then return nil end

  -- find the matching tag from the cache and update faved_by_players list by ensuring the
  -- player's index is in the list. Add it to the list if it does not already exist.
  if existing_tag then
    if not basic_helpers.Helpers.index_is_in_table(existing_tag.faved_by_players, self.player_index) then
      table.insert(existing_tag.faved_by_players, self.player_index)
    end
  end

  -- update the player's storage to include the new addition
  storage.players[self.player_index].surfaces[self.surface_index].favorites[slot_idx] = new_favorite

  -- it is now a favorite in the player's favorites
  return new_favorite
end

--- Remove a favorite by GPS, set slot to blank if not found. Update matched Tag and storage
---@param gps string
function PlayerFavorites:remove_favorite(gps)
  if not gps or type(gps) ~= "string" or gps == "" then return end

  local existing_fave = self:get_favorite_by_gps(gps)
  if not existing_fave then return end

  -- find the index of the favorite to remove
  local remove_idx = Helpers.find_by_predicate(self.favorites, function(v) return v.gps == gps end)
  if not remove_idx then return end

  local existing_tag = Cache.get_tag_by_gps(gps)
  if not existing_tag then return end

  if basic_helpers.Helpers.index_is_in_table(existing_tag.faved_by_players, self.player_index) then
    table.remove(existing_tag.faved_by_players, self.player_index)
  end

  -- update the slot to a blank favorite
  self.favorites[remove_idx] = Favorite.get_blank_favorite()

  storage.players[self.player_index].surfaces[self.surface_index].favorites = self.favorites
end

--- Constructor for PlayerFavorites
---@param player LuaPlayer
---@return PlayerFavorites
function PlayerFavorites.new(player)
  local obj = setmetatable({}, PlayerFavorites)
  obj.player = player
  obj.player_index = player.index
  obj.surface_index = player.surface.index
  --- build a new favorites array filled with blank favorites - dont call cache as it could get circular
  local faves = {}
  for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
    faves[i] = Favorite.get_blank_favorite()
  end
  obj.favorites = faves

  return obj
end

return PlayerFavorites
