---@diagnostic disable: undefined-global

-- core/favorite/player_favorites.lua
-- TeleportFavorites Factorio Mod
-- PlayerFavorites class: manages a collection of favorites for a player, including slot management, persistence, drag-and-drop, and surface-aware data.


local Constants = require("constants")
local FavoriteUtils = require("core.favorite.favorite_utils")
local Cache = require("core.cache.cache")
local BasicHelpers = require("core.utils.basic_helpers")
local GuiObserver = require("core.events.gui_observer")
local FavoriteRehydration = require("core.favorite.favorite_rehydration")
local ErrorHandler = require("core.utils.error_handler")
local _serpent_ok, serpent = pcall(require, "serpent")
if not _serpent_ok then serpent = nil end


--- PlayerFavorites class for managing a player's favorite collection
---@class PlayerFavorites
---@field player LuaPlayer
---@field player_index uint
---@field surface_index uint
---@field favorites Favorite[]
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
    local max_slots = Cache.Settings.get_player_max_favorite_slots(player)
    if ErrorHandler and ErrorHandler.debug_log then
      ErrorHandler.debug_log("[FAV_INIT] Initializing blank favorites array", {
        player = player.name,
        max_slots = max_slots
      })
    end
    for i = 1, max_slots do
      obj.favorites[i] = FavoriteUtils.get_blank_favorite()
    end
    -- Sync to storage after object is fully constructed using Cache module
    Cache.set_player_favorites(player, obj.favorites)
  end

  PlayerFavorites._instances[player_index][surface_index] = obj
  return obj
end

---Remove a favorite GPS from the player's favorites
---@param gps string GPS string to remove
---@return boolean success, string? error_message
function PlayerFavorites:remove_favorite(gps)
  local max_slots = Cache.Settings.get_player_max_favorite_slots(self.player)
  if not gps or type(gps) ~= "string" or gps == "" then
    return false, "invalid_gps"
  end
  local favorites = self.favorites
  if not favorites or #favorites < max_slots then
    return false, "favorites_array_invalid"
  end
  for i = 1, max_slots do
    local fav = favorites[i]
    if fav and fav.gps == gps then
      favorites[i] = FavoriteUtils.get_blank_favorite()
      Cache.set_player_favorites(self.player, favorites)
      -- Notify GUI observer for immediate bar update
      GuiObserver.GuiEventBus.notify("favorite_removed", {
        player_index = self.player_index,
        gps = gps
      })
      return true
    end
  end
  return false, "favorite_not_found"
end

---Add a favorite GPS to the first available slot
---@param gps string GPS string to add
---@return boolean success, string? error_message
function PlayerFavorites:add_favorite(gps)
  local max_slots = Cache.Settings.get_player_max_favorite_slots(self.player)
  if ErrorHandler and ErrorHandler.debug_log then
    local favorited_count = 0
    for i = 1, max_slots do
      local fav = self.favorites and self.favorites[i]
      if fav and fav.gps and fav.gps ~= "" and not BasicHelpers.is_blank_favorite(fav) then
        favorited_count = favorited_count + 1
      end
    end
    ErrorHandler.debug_log("[FAV_ADD] Attempting to add favorite", {
      player = self.player and self.player.name or "<nil>",
      gps = gps,
      max_slots = max_slots,
      favorited_count = favorited_count,
      favorites_len = self.favorites and #self.favorites or 0
    })
  end
  if not gps or type(gps) ~= "string" or gps == "" then
    return false, "invalid_gps"
  end
  local favorites = self.favorites
  if not favorites or #favorites ~= max_slots then
    -- initialize the player's favorites array
    local old_faves = favorites or {}
    for i = 1, max_slots do
      favorites[i] = old_faves[i] or FavoriteUtils.get_blank_favorite()
    end
    if ErrorHandler and ErrorHandler.debug_log then
      ErrorHandler.debug_log("[FAV_ADD] Reinitialized favorites array", {
        player = self.player and self.player.name or "<nil>",
        favorites_len = #favorites,
        max_slots = max_slots
      })
    end
  end
  -- Check for duplicate
  for i = 1, max_slots do
    local fav = favorites[i]
    if fav and fav.gps == gps then
      return true -- Already present, treat as success
    end
  end
  -- Find first available (blank and unlocked) slot
  for i = 1, max_slots do
    local fav = favorites[i] or FavoriteUtils.get_blank_favorite()
    if BasicHelpers.is_blank_favorite(fav) and not (fav.locked == true) then
      favorites[i] = FavoriteUtils.get_blank_favorite()
      favorites[i].gps = gps
      favorites[i].locked = false
      Cache.set_player_favorites(self.player, favorites)
      if ErrorHandler and ErrorHandler.debug_log then
        ErrorHandler.debug_log("[FAV_ADD] Added favorite to slot", {
          player = self.player and self.player.name or "<nil>",
          slot = i,
          gps = gps
        })
      end
      -- Notify GUI observer for immediate bar update
      GuiObserver.GuiEventBus.notify("favorite_added", {
        player_index = self.player_index,
        gps = gps
      })
      return true
    end
  end
  if ErrorHandler and ErrorHandler.debug_log then
    ErrorHandler.debug_log("[FAV_ADD] No available slots", {
      player = self.player and self.player.name or "<nil>",
      favorited_count = favorited_count,
      max_slots = max_slots,
      favorites_len = #favorites
    })
  end
  return false, "favorite_slots_full"
end

---Get a favorite entry by GPS string
---@param gps string GPS string to search for
---@return Favorite|nil favorite_entry The favorite entry if found, or nil
function PlayerFavorites:get_favorite_by_gps(gps)
  if not gps or type(gps) ~= "string" or gps == "" then
    return nil
  end
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

---Toggle the lock state of a favorite slot
---@param slot integer The slot index (1-based)
---@return boolean success, string? error_message
function PlayerFavorites:toggle_favorite_lock(slot)
  local max_slots = Cache.Settings.get_player_max_favorite_slots(self.player)
  if not slot or slot < 1 or slot > max_slots then
    return false, "slot_out_of_range"
  end
  local favorites = self.favorites
  if not favorites or #favorites < max_slots then
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

---Reorder favorites using blank-seeking cascade algorithm (drag-drop)
---@param source_slot integer Source slot index (1-based)
---@param target_slot integer Target slot index (1-based)
---@return boolean success, string? error_message
--- Optimized: In-place mutation, only update changed slots, return affected indices
function PlayerFavorites:reorder_favorites(source_slot, target_slot)
  if not source_slot or not target_slot or source_slot == target_slot then
    return false, "invalid_slot_indices"
  end
  local max_slots = Cache.Settings.get_player_max_favorite_slots(self.player)
  if source_slot < 1 or source_slot > max_slots or target_slot < 1 or target_slot > max_slots then
    return false, "slot_out_of_range"
  end
  local favorites = self.favorites
  if not favorites or #favorites < max_slots then
    return false, "favorites_array_invalid"
  end
  local src_fav = favorites[source_slot]
  local tgt_fav = favorites[target_slot]
  if BasicHelpers.is_locked_favorite(src_fav) or BasicHelpers.is_locked_favorite(tgt_fav) then
    return false, "locked_slot"
  end
  local changed_slots = {}
  -- Blank-seeking cascade algorithm, but in-place
  if BasicHelpers.is_blank_favorite(tgt_fav) then
    favorites[target_slot] = FavoriteUtils.copy(src_fav or FavoriteUtils.get_blank_favorite())
    favorites[source_slot] = FavoriteUtils.get_blank_favorite()
    table.insert(changed_slots, source_slot)
    table.insert(changed_slots, target_slot)
  elseif math.abs(source_slot - target_slot) == 1 then
    favorites[source_slot], favorites[target_slot] = favorites[target_slot], favorites[source_slot]
    table.insert(changed_slots, source_slot)
    table.insert(changed_slots, target_slot)
  else
    -- Cascade: evacuate source, shift items toward blank
    local direction = source_slot < target_slot and 1 or -1
    if direction == 1 then
      for i = source_slot, target_slot - 1 do
        favorites[i] = FavoriteUtils.copy(favorites[i + 1])
        table.insert(changed_slots, i)
      end
    else
      for i = source_slot, target_slot + 1, -1 do
        favorites[i] = FavoriteUtils.copy(favorites[i - 1])
        table.insert(changed_slots, i)
      end
    end
    favorites[target_slot] = FavoriteUtils.copy(src_fav or FavoriteUtils.get_blank_favorite())
    table.insert(changed_slots, target_slot)
  end
  Cache.set_player_favorites(self.player, favorites)
  return true, changed_slots
end

--- Update GPS coordinates across all players and return list of affected players
---@param old_gps string Original GPS coordinate string
---@param new_gps string New GPS coordinate string
---@param acting_player_index uint? Player index who initiated the change (excluded from results)
---@return LuaPlayer[] affected_players List of players whose favorites were updated
function PlayerFavorites.update_gps_for_all_players(old_gps, new_gps, acting_player_index)
    if ErrorHandler and ErrorHandler.debug_log then
      ErrorHandler.debug_log("[FAV_UPDATE_ALL] Called update_gps_for_all_players", {
        old_gps = old_gps,
        new_gps = new_gps,
        acting_player_index = acting_player_index
      })
    end
  if not old_gps or not new_gps or old_gps == new_gps then
    return {}
  end

  local affected_players = {}

  for player_index, player in pairs(game.players) do
    if player and player.valid and player_index ~= acting_player_index then
      local surface_index = player.surface.index
      local raw_favorites = Cache.get_player_favorites(player, surface_index)
      if raw_favorites then
        local needs_update = false
        for i = 1, #raw_favorites do
          local fav = raw_favorites[i]
          if fav and fav.gps == old_gps then
            needs_update = true
            break
          end
        end
        if needs_update then
          if ErrorHandler and ErrorHandler.debug_log then
            ErrorHandler.debug_log("[FAV_UPDATE_ALL] Player needs GPS update", {
              player = player.name,
              player_index = player_index,
              old_gps = old_gps,
              new_gps = new_gps
            })
          end
          local max_slots = Cache.Settings.get_player_max_favorite_slots(player)
          local favorites = PlayerFavorites.new(player)
          local was_updated = favorites:update_gps_coordinates(old_gps, new_gps, max_slots)
          if was_updated then
            table.insert(affected_players, player)
          end
        end
      end
    end
  end
  return affected_players
end

--- Update GPS coordinates for all favorites that match the old GPS
---@param old_gps string Original GPS coordinate string
---@param new_gps string New GPS coordinate string
---@param provided_max_slots integer? Pre-fetched max slots (avoids redundant settings lookup)
---@return boolean any_updated True if any favorites were updated
function PlayerFavorites:update_gps_coordinates(old_gps, new_gps, provided_max_slots)
    if ErrorHandler and ErrorHandler.debug_log then
      ErrorHandler.debug_log("[FAV_UPDATE] Called update_gps_coordinates", {
        player = self.player and self.player.name or "<nil>",
        player_index = self.player_index,
        old_gps = old_gps,
        new_gps = new_gps
      })
    end
  if not old_gps or not new_gps or old_gps == new_gps then
    return false
  end

  local any_updated = false
  local max_slots = provided_max_slots or Cache.Settings.get_player_max_favorite_slots(self.player)
  for i = 1, max_slots do
    local fav = self.favorites[i] or FavoriteUtils.get_blank_favorite()
    if fav and not FavoriteUtils.is_blank_favorite(fav) and fav.gps == old_gps then
      fav.gps = new_gps

      -- CRITICAL: Also update the tag.gps if tag exists
      if fav.tag and fav.tag.gps then
        fav.tag.gps = new_gps
      end

      -- Rehydrate favorite to ensure latest tag/icon info after move
      if FavoriteRehydration and FavoriteRehydration.rehydrate_favorite_at_runtime then
        local player = self.player
        if player and player.valid then
          self.favorites[i] = FavoriteRehydration.rehydrate_favorite_at_runtime(player, fav)
        end
      end

      if ErrorHandler and ErrorHandler.debug_log then
        ErrorHandler.debug_log("[FAV_UPDATE] Favorite GPS updated and rehydrated in slot", {
          player = self.player and self.player.name or "<nil>",
          slot = i,
          old_gps = old_gps,
          new_gps = new_gps
        })
        -- Dump the full favorites array after update for storage inspection
        if serpent and serpent.block then
          -- Sanitize favorites before dumping to avoid userdata/functions in logs
          local ok, sanitized = pcall(function() return Cache.sanitize_for_storage(self.favorites) end)
          if not ok then sanitized = {} end
          if ErrorHandler and ErrorHandler.debug_log then
            ErrorHandler.debug_log("[FAV_UPDATE][DUMP] Full favorites array after GPS update:\n" .. serpent.block(sanitized))
          end
        end
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

  return any_updated
end

---Returns the number of available (blank) favorite slots for the player.
---@return integer available_slots Number of blank slots
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

return PlayerFavorites
