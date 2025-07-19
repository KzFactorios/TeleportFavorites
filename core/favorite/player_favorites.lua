---@diagnostic disable: undefined-global

-- core/favorite/player_favorites.lua
-- TeleportFavorites Factorio Mod
-- PlayerFavorites class: manages a collection of favorites for a player, including slot management, persistence, drag-and-drop, and surface-aware data.

local Constants = require("constants")
local FavoriteUtils = require("core.favorite.favorite")
local Cache = require("core.cache.cache")
local GuiObserver = _G.GuiObserver or require("core.events.gui_observer")

--- PlayerFavorites class for managing a player's favorite collection
--- @class PlayerFavorites
--- @field player LuaPlayer
--- @field player_index uint
--- @field surface_index uint
--- @field favorites Favorite[]
local PlayerFavorites = {}
PlayerFavorites.__index = PlayerFavorites
PlayerFavorites._instances = PlayerFavorites._instances or {}

--- Constructor for PlayerFavorites
---@param player LuaPlayer
---@return PlayerFavorites
function PlayerFavorites.new(player)
  if not player or not player.valid then
    error("PlayerFavorites.new: Invalid player provided")
  end

  local player_index = player.index
  local surface_index = player.surface.index
  PlayerFavorites._instances[player_index] = PlayerFavorites._instances[player_index] or {}
  if PlayerFavorites._instances[player_index][surface_index] then
    return PlayerFavorites._instances[player_index][surface_index]
  end

  local obj = setmetatable({}, PlayerFavorites)
  obj.player = player
  obj.player_index = player_index
  obj.surface_index = surface_index

  -- Initialize favorites array from storage or create new
  local stored_favorites = Cache.get_player_favorites(player)
  if stored_favorites and #stored_favorites > 0 then
    obj.favorites = stored_favorites
  else
    -- Create new blank favorites array
    obj.favorites = {}
    for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
      obj.favorites[i] = FavoriteUtils.get_blank_favorite()
    end
    -- Sync to storage after object is fully constructed using Cache module
    if player and player.valid then
      Cache.set_player_favorites(player, obj.favorites)
    end
  end

  PlayerFavorites._instances[player_index][surface_index] = obj
  return obj
end

--- Update GPS coordinates across all players and return list of affected players
---@param old_gps string Original GPS coordinate string
---@param new_gps string New GPS coordinate string
---@param acting_player_index uint? Player index who initiated the change (excluded from results)
---@return LuaPlayer[] affected_players List of players whose favorites were updated
function PlayerFavorites.update_gps_for_all_players(old_gps, new_gps, acting_player_index)
  if not old_gps or not new_gps or old_gps == new_gps then
    return {}
  end

  local affected_players = {}

  for player_index, player in pairs(game.players) do
    if player and player.valid and player_index ~= acting_player_index then
      local favorites = PlayerFavorites.new(player)
      -- Only update if the player's favorite is still old_gps (not already updated)
      local needs_update = false
      for i = 1, #favorites.favorites do
        local fav = favorites.favorites[i]
        if fav and fav.gps == old_gps then
          needs_update = true
          break
        end
      end
      if needs_update then
        local was_updated = favorites:update_gps_coordinates(old_gps, new_gps)
        if was_updated then
          table.insert(affected_players, player)
        end
      end
    end
  end
  return affected_players
end

--- Update GPS coordinates for all favorites that match the old GPS
---@param old_gps string Original GPS coordinate string
---@param new_gps string New GPS coordinate string
---@return boolean any_updated True if any favorites were updated
function PlayerFavorites:update_gps_coordinates(old_gps, new_gps)
  if not old_gps or not new_gps or old_gps == new_gps then
    return false
  end

  local any_updated = false
  for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
    local fav = self.favorites[i]
    if fav and not FavoriteUtils.is_blank_favorite(fav) and fav.gps == old_gps then
      fav.gps = new_gps

      -- CRITICAL: Also update the tag.gps if tag exists
      if fav.tag and fav.tag.gps then
        fav.tag.gps = new_gps
      end

      any_updated = true
    end
  end

  if any_updated then
    local player = self.player
    if player and player.valid then
      Cache.set_player_favorites(player, self.favorites)
    end

    -- Notify observers of GPS update
    if GuiObserver and GuiObserver.GuiEventBus then
      GuiObserver.GuiEventBus.notify("favorites_gps_updated", {
        player_index = self.player_index,
        old_gps = old_gps,
        new_gps = new_gps
      })

      -- CRITICAL: Trigger cache_updated to rebuild favorites bar
      GuiObserver.GuiEventBus.notify("cache_updated", {
        type = "favorites_gps_updated",
        player_index = self.player_index,
        old_gps = old_gps,
        new_gps = new_gps
      })
    end
  end

  return any_updated
end

return PlayerFavorites
