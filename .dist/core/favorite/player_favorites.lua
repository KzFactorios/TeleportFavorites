---@diagnostic disable: undefined-global

local Constants = require("constants")
local FavoriteUtils = require("core.favorite.favorite_utils")
local Cache = require("core.cache.cache")
local BasicHelpers = require("core.utils.basic_helpers")
local GuiObserver = require("core.events.gui_observer")


---@class PlayerFavorites
---@field player LuaPlayer
---@field player_index uint
---@field surface_index uint
---@field favorites Favorite[]
local PlayerFavorites = {}
PlayerFavorites.__index = PlayerFavorites
PlayerFavorites._instances = PlayerFavorites._instances or {}


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

  local stored_favorites = Cache.get_player_favorites(player)
  if stored_favorites and #stored_favorites > 0 then
    obj.favorites = stored_favorites
  else
    obj.favorites = {}
    for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
      obj.favorites[i] = FavoriteUtils.get_blank_favorite()
    end
    if player and player.valid then
      Cache.set_player_favorites(player, obj.favorites)
    end
  end

  PlayerFavorites._instances[player_index][surface_index] = obj
  return obj
end

---@param gps string GPS string to remove
---@return boolean success, string? error_message
function PlayerFavorites:remove_favorite(gps)
  local max_slots = Constants.settings.MAX_FAVORITE_SLOTS
  if not gps or type(gps) ~= "string" or gps == "" then
    return false, "invalid_gps"
  end
  local favorites = self.favorites
  if not favorites or #favorites ~= max_slots then
    return false, "favorites_array_invalid"
  end
  for i = 1, max_slots do
    local fav = favorites[i]
    if fav and fav.gps == gps then
      favorites[i] = FavoriteUtils.get_blank_favorite()
      Cache.set_player_favorites(self.player, favorites)
      return true
    end
  end
  return false, "favorite_not_found"
end

---@param gps string GPS string to add
---@return boolean success, string? error_message
function PlayerFavorites:add_favorite(gps)
  local max_slots = Constants.settings.MAX_FAVORITE_SLOTS
  if not gps or type(gps) ~= "string" or gps == "" then
    return false, "invalid_gps"
  end
  local favorites = self.favorites
  if not favorites or #favorites ~= max_slots then
    return false, "favorites_array_invalid"
  end
  for i = 1, max_slots do
    local fav = favorites[i]
    if fav and fav.gps == gps then
      return true
    end
  end
  for i = 1, max_slots do
    local fav = favorites[i]
    if BasicHelpers.is_blank_favorite(fav) and not fav.locked then
      favorites[i].gps = gps
      favorites[i].locked = false
      Cache.set_player_favorites(self.player, favorites)
      return true
    end
  end
  return false, "favorite_slots_full"
end

---@param gps string GPS string to search for
---@return Favorite|nil favorite_entry The favorite entry if found, or nil
function PlayerFavorites:get_favorite_by_gps(gps)
  if not gps or type(gps) ~= "string" or gps == "" then
    return nil
  end
  local max_slots = Constants.settings.MAX_FAVORITE_SLOTS
  local favorites = self.favorites
  if not favorites or #favorites ~= max_slots then
    return nil
  end
  for i = 1, max_slots do
    local fav = favorites[i]
    if fav and fav.gps == gps then
      return fav
    end
  end
  return nil
end

---@param slot integer The slot index (1-based)
---@return boolean success, string? error_message
function PlayerFavorites:toggle_favorite_lock(slot)
  local max_slots = Constants.settings.MAX_FAVORITE_SLOTS
  if not slot or slot < 1 or slot > max_slots then
    return false, "slot_out_of_range"
  end
  local favorites = self.favorites
  if not favorites or #favorites ~= max_slots then
    return false, "favorites_array_invalid"
  end
  local fav = favorites[slot]
  if not fav then
    return false, "favorite_not_found"
  end
  if BasicHelpers.is_blank_favorite(fav) then
    return false, "cannot_lock_blank_slot"
  end
  fav.locked = not fav.locked
  favorites[slot] = fav
  Cache.set_player_favorites(self.player, favorites)
  return true
end

---@param source_slot integer Source slot index (1-based)
---@param target_slot integer Target slot index (1-based)
---@return boolean success, string? error_message
function PlayerFavorites:reorder_favorites(source_slot, target_slot)
  if not source_slot or not target_slot or source_slot == target_slot then
    return false, "invalid_slot_indices"
  end
  local max_slots = Constants.settings.MAX_FAVORITE_SLOTS
  if source_slot < 1 or source_slot > max_slots or target_slot < 1 or target_slot > max_slots then
    return false, "slot_out_of_range"
  end
  local favorites = self.favorites
  if not favorites or #favorites ~= max_slots then
    return false, "favorites_array_invalid"
  end
  local src_fav = favorites[source_slot]
  local tgt_fav = favorites[target_slot]
  if BasicHelpers.is_locked_favorite(src_fav) or BasicHelpers.is_locked_favorite(tgt_fav) then
    return false, "locked_slot"
  end
  local new_favorites = {}
  for i = 1, max_slots do
    new_favorites[i] = FavoriteUtils.copy(favorites[i])
  end
  if BasicHelpers.is_blank_favorite(tgt_fav) then
    new_favorites[target_slot] = FavoriteUtils.copy(src_fav)
    new_favorites[source_slot] = FavoriteUtils.get_blank_favorite()
  elseif math.abs(source_slot - target_slot) == 1 then
    new_favorites[source_slot], new_favorites[target_slot] = new_favorites[target_slot], new_favorites[source_slot]
  else
    local direction = source_slot < target_slot and 1 or -1
    local range_start, range_end = source_slot, target_slot
    if direction == 1 then
      for i = source_slot, target_slot - 1 do
        new_favorites[i] = FavoriteUtils.copy(new_favorites[i + 1])
      end
    else
      for i = source_slot, target_slot + 1, -1 do
        new_favorites[i] = FavoriteUtils.copy(new_favorites[i - 1])
      end
    end
    new_favorites[target_slot] = FavoriteUtils.copy(src_fav)
  end
  self.favorites = new_favorites
  Cache.set_player_favorites(self.player, new_favorites)
  return true
end

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

    if GuiObserver and GuiObserver.GuiEventBus then
      GuiObserver.GuiEventBus.notify("favorites_gps_updated", {
        player_index = self.player_index,
        old_gps = old_gps,
        new_gps = new_gps
      })

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

---@return integer available_slots Number of blank slots
function PlayerFavorites:available_slots()
  local count = 0
  for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
    local fav = self.favorites[i]
    if fav and FavoriteUtils.is_blank_favorite(fav) then
      count = count + 1
    end
  end
  return count
end

return PlayerFavorites
