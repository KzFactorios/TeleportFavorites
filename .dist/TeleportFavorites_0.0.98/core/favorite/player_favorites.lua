local Deps = require("core.deps_barrel")
local BasicHelpers, Cache =
  Deps.BasicHelpers, Deps.Cache
local FavoriteUtils = require("core.favorite.favorite_utils")
local function is_invalid_gps(gps)
  return not gps or type(gps) ~= "string" or gps == ""
end
local function notify_fave(self, event_name, extra)
  local payload = extra or {}
  payload.player_index = self.player_index
  Cache.notify_observers_safe(event_name, payload)
end
local function check_favorites_array(favorites, max_slots)
  if not favorites or #favorites < max_slots then
    return false, "favorites_array_invalid"
  end
  return true
end
local PlayerFavorites = {}
PlayerFavorites.__index = PlayerFavorites
PlayerFavorites._instances = PlayerFavorites._instances or {}
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
  local max_slots = Cache.Settings.get_player_max_favorite_slots(player)
  for i = 1, max_slots do
      obj.favorites[i] = FavoriteUtils.get_blank_favorite()
    end
  Cache.set_player_favorites(player, obj.favorites)
  end
  PlayerFavorites._instances[player_index][surface_index] = obj
  return obj
end
function PlayerFavorites:remove_favorite(gps, silent)
  local max_slots = Cache.Settings.get_player_max_favorite_slots(self.player)
  if is_invalid_gps(gps) then return false, "invalid_gps", nil end
  local favorites = self.favorites
  local ok, err = check_favorites_array(favorites, max_slots)
  if not ok then return false, err, nil end
  for i = 1, max_slots do
    local fav = favorites[i]
    if fav and fav.gps == gps then
      favorites[i] = FavoriteUtils.get_blank_favorite()
      Cache.set_player_favorites(self.player, favorites)
      if not silent then
        notify_fave(self, "favorite_removed", { gps = gps, slot = i })
      end
      return true, nil, i
    end
  end
  return false, "favorite_not_found", nil
end
function PlayerFavorites:add_favorite(gps, silent)
  local max_slots = Cache.Settings.get_player_max_favorite_slots(self.player)
  if is_invalid_gps(gps) then return false, "invalid_gps", nil end
  local favorites = self.favorites
  if not favorites or #favorites ~= max_slots then
    local old_faves = favorites or {}
    for i = 1, max_slots do
      favorites[i] = old_faves[i] or FavoriteUtils.get_blank_favorite()
    end
  end
  for i = 1, max_slots do
    local fav = favorites[i]
    if fav and fav.gps == gps then
      return true, nil, i
    end
  end
  for i = 1, max_slots do
    local fav = favorites[i] or FavoriteUtils.get_blank_favorite()
    if FavoriteUtils.is_blank_favorite(fav) then
      favorites[i] = FavoriteUtils.get_blank_favorite()
      favorites[i].gps = gps
      favorites[i].locked = false
      Cache.set_player_favorites(self.player, favorites)
      if not silent then
        notify_fave(self, "favorite_added", { gps = gps, slot = i })
      end
      return true, nil, i
    end
  end
  return false, "favorite_slots_full", nil
end
function PlayerFavorites:get_favorite_by_gps(gps)
  if is_invalid_gps(gps) then return nil end
  local max_slots = Cache.Settings.get_player_max_favorite_slots(self.player)
  local favorites = self.favorites
  if not favorites or #favorites < max_slots then
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
function PlayerFavorites:toggle_favorite_lock(slot)
  local max_slots = Cache.Settings.get_player_max_favorite_slots(self.player)
  if not slot or slot < 1 or slot > max_slots then
    return false, "slot_out_of_range"
  end
  local favorites = self.favorites
  local ok, err = check_favorites_array(favorites, max_slots)
  if not ok then return false, err end
  local fav = favorites[slot]
  if not fav then
    return false, "favorite_not_found"
  end
  if FavoriteUtils.is_blank_favorite(fav) then
    return false, "cannot_lock_blank_slot"
  end
  fav.locked = not fav.locked
  Cache.set_player_favorites(self.player, favorites)
  notify_fave(self, "favorite_updated", { slot = slot })
  return true
end
function PlayerFavorites:reorder_favorites(source_slot, target_slot)
  if not source_slot or not target_slot or source_slot == target_slot then
    return false, "invalid_slot_indices"
  end
  local max_slots = Cache.Settings.get_player_max_favorite_slots(self.player)
  if source_slot < 1 or source_slot > max_slots or target_slot < 1 or target_slot > max_slots then
    return false, "slot_out_of_range"
  end
  local favorites = self.favorites
  local ok, err = check_favorites_array(favorites, max_slots)
  if not ok then return false, err end
  local src_fav = favorites[source_slot]
  local tgt_fav = favorites[target_slot]
  if BasicHelpers.is_locked_favorite(src_fav) or BasicHelpers.is_locked_favorite(tgt_fav) then
    return false, "locked_slot"
  end
  local new_favorites = {}
  for i = 1, max_slots do
    new_favorites[i] = FavoriteUtils.copy_for_reorder(favorites[i] or FavoriteUtils.get_blank_favorite())
  end
  if FavoriteUtils.is_blank_favorite(tgt_fav) then
    new_favorites[target_slot] = FavoriteUtils.copy_for_reorder(src_fav or FavoriteUtils.get_blank_favorite())
    new_favorites[source_slot] = FavoriteUtils.get_blank_favorite()
  elseif math.abs(source_slot - target_slot) == 1 then
    new_favorites[source_slot], new_favorites[target_slot] = new_favorites[target_slot], new_favorites[source_slot]
  else
    local direction = source_slot < target_slot and 1 or -1
    if direction == 1 then
      for i = source_slot, target_slot - 1 do
        new_favorites[i] = FavoriteUtils.copy_for_reorder(new_favorites[i + 1])
      end
    else
      for i = source_slot, target_slot + 1, -1 do
        new_favorites[i] = FavoriteUtils.copy_for_reorder(new_favorites[i - 1])
      end
    end
    new_favorites[target_slot] = FavoriteUtils.copy_for_reorder(src_fav or FavoriteUtils.get_blank_favorite())
  end
  local changed_indices = {}
  for i = 1, max_slots do
    if not FavoriteUtils.same_visual_identity(favorites[i], new_favorites[i]) then
      changed_indices[#changed_indices + 1] = i
    end
  end
  self.favorites = new_favorites
  Cache.set_player_favorites(self.player, new_favorites)
  notify_fave(self, "favorite_updated", { slot = source_slot })
  notify_fave(self, "favorite_updated", { slot = target_slot })
  return true, nil, changed_indices
end
function PlayerFavorites.update_gps_for_all_players(old_gps, new_gps, acting_player_index)
  if not old_gps or not new_gps or old_gps == new_gps then
    return {}
  end
  local affected_players = {}
  BasicHelpers.for_each_player_by_index_asc(function(player, player_index)
    if player_index ~= acting_player_index then
      local favorites = PlayerFavorites.new(player)
      if favorites:update_gps_coordinates(old_gps, new_gps) then
        table.insert(affected_players, player)
      end
    end
  end)
  return affected_players
end
function PlayerFavorites:update_gps_coordinates(old_gps, new_gps)
  if not old_gps or not new_gps or old_gps == new_gps then
    return false
  end
  local any_updated = false
  local max_slots = Cache.Settings.get_player_max_favorite_slots(self.player)
  for i = 1, max_slots do
    local fav = self.favorites[i] or FavoriteUtils.get_blank_favorite()
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
  end
  return any_updated
end
function PlayerFavorites:available_slots()
  local count = 0
  local max_slots = Cache.Settings.get_player_max_favorite_slots(self.player)
  for i = 1, max_slots do
    local fav = self.favorites[i]
    if fav and FavoriteUtils.is_blank_favorite(fav) then
      count = count + 1
    end
  end
  return count
end
function PlayerFavorites:has_blank_slot()
  local max_slots = Cache.Settings.get_player_max_favorite_slots(self.player)
  for i = 1, max_slots do
    local fav = self.favorites[i]
    if fav and FavoriteUtils.is_blank_favorite(fav) then
      return true
    end
  end
  return false
end
function PlayerFavorites.rehydrate_favorite_at_runtime(player, fav)
  if not player then return FavoriteUtils.get_blank_favorite() end
  if not fav or type(fav) ~= "table" or not fav.gps or fav.gps == "" or FavoriteUtils.is_blank_favorite(fav) then
    return FavoriteUtils.get_blank_favorite()
  end
  local tag = Cache.get_tag_by_gps(player, fav.gps)
  return FavoriteUtils.new(fav.gps, fav.locked or false, tag)
end
function PlayerFavorites.invalidate_instance_cache_for_player(player_index)
  if not player_index then return end
  PlayerFavorites._instances[player_index] = nil
end
return PlayerFavorites
