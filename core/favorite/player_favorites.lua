---@diagnostic disable: undefined-global
--[[
core/favorite/player_favorites.lua
TeleportFavorites Factorio Mod
-----------------------------
PlayerFavorites class: manages a collection of favorites for a specific player.

- Provides essential interface for favorite collection operations
- Handles slot management, lookup, persistence, and favorite manipulation
- All persistent data is managed via the Cache module and is surface-aware
- Used for favorites bar, tag editor, and all player favorite operations

Core Features:
--------------
- Add/remove favorites with automatic slot management
- Reorder favorites with drag-and-drop support
- Lock/unlock favorites to prevent accidental changes
- Find favorites by GPS string
- Automatic tag synchronization and cleanup
- GPS coordinate updates across all players

Methods:
--------
- new(player) - Constructor
- get_favorite_by_gps(gps) - Find favorite by GPS string
- add_favorite(gps) - Add new favorite
- remove_favorite(gps) - Remove favorite by GPS
- move_favorite(from_slot, to_slot) - Reorder favorites
- toggle_favorite_lock(slot_idx) - Lock/unlock favorite
- update_gps_coordinates(old_gps, new_gps) - Update GPS for this player
- update_gps_for_all_players(old_gps, new_gps, acting_player_index) - Static GPS update

Notes:
------
- All slot management is 1-based and respects MAX_FAVORITE_SLOTS from Constants
- Blank slots are always filled with Favorite.get_blank_favorite()
- All persistent data is surface-aware and managed via Cache
- Operations maintain consistency between instance state and storage
--]]

local Constants = require("constants")
local FavoriteUtils = require("core.favorite.favorite")
local Cache = require("core.cache.cache")
local ErrorHandler = require("core.utils.error_handler")
local GuiObserver = require("core.pattern.gui_observer")

-- Observer Pattern Integration
local function notify_observers_safe(event_type, data)
  GuiObserver.GuiEventBus.notify(event_type, data)
end

-- Use Cache.sanitize_for_storage to sanitize tags for favorites
local function sanitize_tag_for_favorite(tag)
  -- Exclude 'chart_tag' userdata but keep all other tag data for rehydration
  local sanitized = Cache.sanitize_for_storage(tag, { chart_tag = true })
  
  ErrorHandler.debug_log("[PLAYER_FAVORITES] Tag sanitized for favorite storage", {
    gps = tag and tag.gps or nil,
    original_has_chart_tag = tag and tag.chart_tag ~= nil,
    original_has_icon = tag and tag.chart_tag and tag.chart_tag.icon ~= nil
  })
  
  return sanitized
end

--- PlayerFavorites class for managing a player's favorite collection
--- @class PlayerFavorites
--- @field player LuaPlayer
--- @field player_index uint
--- @field surface_index uint
--- @field favorites Favorite[]
local PlayerFavorites = {}
PlayerFavorites.__index = PlayerFavorites

-- Private helper methods

--- Validate slot index is within bounds
---@param slot_idx number
---@return boolean
local function is_valid_slot(slot_idx)
  return type(slot_idx) == "number" and slot_idx >= 1 and slot_idx <= Constants.settings.MAX_FAVORITE_SLOTS
end

--- Update storage with current favorites state
---@param self PlayerFavorites
local function sync_to_storage(self)
  if not storage.players then storage.players = {} end
  if not storage.players[self.player_index] then storage.players[self.player_index] = {} end
  if not storage.players[self.player_index].surfaces then storage.players[self.player_index].surfaces = {} end

  storage.players[self.player_index].surfaces[self.surface_index] =
      storage.players[self.player_index].surfaces[self.surface_index] or {}
  storage.players[self.player_index].surfaces[self.surface_index].favorites = self.favorites
end

--- Update tag's faved_by_players list
---@param tag table
---@param player_index uint
---@param action "add"|"remove"
local function update_tag_favorites(tag, player_index, action)
  if not tag or not tag.faved_by_players then return end

  ---@type integer?
  local found_index = nil
  for i, pid in ipairs(tag.faved_by_players) do
    if pid == player_index then
      found_index = i
      break
    end
  end

  if action == "add" then
    if not found_index then
      table.insert(tag.faved_by_players, player_index)
    end
  else
    -- action == "remove"
    if found_index then
      table.remove(tag.faved_by_players, found_index)
    end
  end
end

-- Public methods

--- Constructor for PlayerFavorites
---@param player LuaPlayer
---@return PlayerFavorites
function PlayerFavorites.new(player)
  if not player or not player.valid then
    error("PlayerFavorites.new: Invalid player provided")
  end

  local obj = setmetatable({}, PlayerFavorites)
  obj.player = player
  obj.player_index = player.index
  obj.surface_index = player.surface.index

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
    -- Sync to storage after object is fully constructed
    if not storage.players then storage.players = {} end
    if not storage.players[obj.player_index] then storage.players[obj.player_index] = {} end
    if not storage.players[obj.player_index].surfaces then storage.players[obj.player_index].surfaces = {} end

    storage.players[obj.player_index].surfaces[obj.surface_index] =
        storage.players[obj.player_index].surfaces[obj.surface_index] or {}
    storage.players[obj.player_index].surfaces[obj.surface_index].favorites = obj.favorites
  end

  return obj
end

--- Get a favorite by GPS string
---@param gps string
---@return Favorite|nil, number|nil slot_index
function PlayerFavorites:get_favorite_by_gps(gps)
  if not gps or type(gps) ~= "string" then return nil, nil end

  for i, fav in ipairs(self.favorites) do
    if fav and fav.gps == gps then
      return fav, i
    end
  end
  return nil, nil
end

-- Removed unused methods: get_favorite_by_slot, get_all_favorites, set_favorites

--- Add a favorite to the first available slot
---@param gps string
---@return Favorite|nil, string|nil error_message
function PlayerFavorites:add_favorite(gps)
  ErrorHandler.debug_log("PlayerFavorites:add_favorite called", {
    player = (self.player and self.player.valid and self.player.name) or "unknown",
    gps = gps,
    gps_type = type(gps)
  })
  if not gps or type(gps) ~= "string" or gps == "" then
    ErrorHandler.debug_log("Invalid GPS string", {
      player = (self.player and self.player.valid and self.player.name) or "unknown",
      gps = gps,
      gps_type = type(gps)
    })
    return nil, "Invalid GPS string"
  end

  local player = self.player
  if not player then return nil, "player not available" end

  -- Check if already exists
  local existing_fav, existing_slot = self:get_favorite_by_gps(gps)
  if existing_fav then
    ErrorHandler.debug_log("Favorite already exists", {
      player = (self.player and self.player.valid and self.player.name) or "unknown",
      gps = gps,
      slot = existing_slot
    })
    return existing_fav, nil
  end
  -- Find first available slot
  local slot_idx = nil
  ErrorHandler.debug_log("Looking for available slot", {
    player = (self.player and self.player.valid and self.player.name) or "unknown",
    max_slots = Constants.settings.MAX_FAVORITE_SLOTS,
    current_favorites_count = #self.favorites
  })
  for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
    ErrorHandler.debug_log("Checking slot", {
      player = (self.player and self.player.valid and self.player.name) or "unknown",
      slot = i,
      favorite = self.favorites[i],
      is_blank = FavoriteUtils.is_blank_favorite(self.favorites[i])
    })
    if FavoriteUtils.is_blank_favorite(self.favorites[i]) then
      slot_idx = i
      break
    end
  end
  if not slot_idx then
    ErrorHandler.debug_log("No available slots", {
      player = (self.player and self.player.valid and self.player.name) or "unknown",
      max_slots = Constants.settings.MAX_FAVORITE_SLOTS
    })
    return nil, "No available slots (maximum " .. Constants.settings.MAX_FAVORITE_SLOTS .. " favorites)"
  end

  ErrorHandler.debug_log("Found available slot", {
    player = (self.player and self.player.valid and self.player.name) or "unknown",
    slot = slot_idx
  })
  -- Get or create tag
  local existing_tag = Cache.get_tag_by_gps(player, gps)
  local tag_for_favorite = existing_tag and sanitize_tag_for_favorite(existing_tag) or nil
  local new_favorite = FavoriteUtils.new(gps, false, tag_for_favorite)
  ErrorHandler.debug_log("Created new favorite", {
    player = (self.player and self.player.valid and self.player.name) or "unknown",
    gps = gps,
    slot = slot_idx,
    favorite = new_favorite
  })
  if existing_tag then
    update_tag_favorites(existing_tag, self.player_index, "add")
  end
  self.favorites[slot_idx] = new_favorite
  sync_to_storage(self)
  -- Only notify if a favorite was actually added
  notify_observers_safe("favorite_added", {
    player_index = self.player_index,
    favorite = new_favorite,
    slot_index = slot_idx
  })
  return new_favorite, nil
end

--- Remove a favorite by GPS string
---@param gps string
---@return boolean success, string|nil error_message
function PlayerFavorites:remove_favorite(gps)
  if not gps or type(gps) ~= "string" or gps == "" then
    return false, "Invalid GPS string"
  end
  local existing_fav, slot_idx = self:get_favorite_by_gps(gps)
  if not existing_fav or not slot_idx then
    return false, "Favorite not found"
  end
  local player = self.player
  if not player then return false end

  local existing_tag = Cache.get_tag_by_gps(player, gps)
  if existing_tag then
    update_tag_favorites(existing_tag, self.player_index, "remove")
  end
  self.favorites[slot_idx] = FavoriteUtils.get_blank_favorite()
  sync_to_storage(self)
  -- Only notify if a favorite was actually removed
  notify_observers_safe("favorite_removed", {
    player_index = self.player_index,
    gps = gps,
    slot_index = slot_idx
  })
  return true, nil
end

-- Removed unused methods: remove_favorite_by_slot, modify_slot, swap_slots

--- Move a favorite from one slot to another
---@param from_slot number
---@param to_slot number
---@return boolean success, string|nil error_message
function PlayerFavorites:move_favorite(from_slot, to_slot)
  if not is_valid_slot(from_slot) or not is_valid_slot(to_slot) then
    return false, "Invalid slot indices"
  end
  if from_slot == to_slot then return true, nil end

  local fav = self.favorites[from_slot]
  if FavoriteUtils.is_blank_favorite(fav) then
    return false, "Cannot move blank favorite"
  end
  if fav and fav.locked then
    return false, "Cannot move locked favorite"
  end

  -- Store the favorite being moved
  local moved_fav = self.favorites[from_slot]
  
  -- Create a copy of the favorites array to work with
  local new_favorites = {}
  for i = 1, #self.favorites do
    new_favorites[i] = self.favorites[i]
  end
  
  -- Remove the favorite from the source position by setting it to blank
  new_favorites[from_slot] = FavoriteUtils.get_blank_favorite()
  
  -- Determine the direction of the move
  if from_slot < to_slot then
    -- Moving forward: shift items between from_slot and to_slot backward
    for i = from_slot, to_slot - 1 do
      new_favorites[i] = self.favorites[i + 1]
    end
  else
    -- Moving backward: shift items between to_slot and from_slot forward
    for i = from_slot, to_slot + 1, -1 do
      new_favorites[i] = self.favorites[i - 1]
    end
  end
  
  -- Place the moved favorite at the destination
  new_favorites[to_slot] = moved_fav
  
  -- Update the favorites array
  self.favorites = new_favorites

  -- Ensure array stays correct size
  while #self.favorites < Constants.settings.MAX_FAVORITE_SLOTS do
    table.insert(self.favorites, FavoriteUtils.get_blank_favorite())
  end
  while #self.favorites > Constants.settings.MAX_FAVORITE_SLOTS do
    table.remove(self.favorites)
  end

  sync_to_storage(self)
  return true, nil
end

--- Toggle the locked state of a favorite
---@param slot_idx number
---@return boolean success, string|nil error_message
function PlayerFavorites:toggle_favorite_lock(slot_idx)
  if not is_valid_slot(slot_idx) then
    return false, "Invalid slot index"
  end

  local fav = self.favorites[slot_idx]
  if not fav or FavoriteUtils.is_blank_favorite(fav) then
    return false, "Cannot lock blank favorite"
  end

  FavoriteUtils.toggle_locked(fav)
  sync_to_storage(self)
  return true, nil
end

-- Removed unused utility methods: is_full, get_favorite_count, get_first_empty_slot, compact, validate

--- Update GPS coordinates for all favorites that match the old GPS
---@param old_gps string Original GPS coordinate string
---@param new_gps string New GPS coordinate string
---@return boolean any_updated True if any favorites were updated
function PlayerFavorites:update_gps_coordinates(old_gps, new_gps)
  if not old_gps or not new_gps or old_gps == new_gps then
    return false
  end

  ErrorHandler.debug_log("PlayerFavorites updating GPS coordinates", {
    player_index = self.player_index,
    old_gps = old_gps,
    new_gps = new_gps
  })

  local any_updated = false
  for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
    local fav = self.favorites[i]
    if fav and not FavoriteUtils.is_blank_favorite(fav) and fav.gps == old_gps then
      ErrorHandler.debug_log("Updating favorite GPS coordinates", {
        player_index = self.player_index,
        slot = i,
        old_gps = old_gps,
        new_gps = new_gps,
        fav_gps_before = fav.gps,
        fav_tag_gps_before = fav.tag and fav.tag.gps or "nil"
      })
      
      fav.gps = new_gps
      
      -- CRITICAL: Also update the tag.gps if tag exists
      if fav.tag and fav.tag.gps then
        fav.tag.gps = new_gps
      end
      
      ErrorHandler.debug_log("Updated favorite GPS coordinates", {
        player_index = self.player_index,
        slot = i,
        fav_gps_after = fav.gps,
        fav_tag_gps_after = fav.tag and fav.tag.gps or "nil"
      })
      
      any_updated = true
    end
  end
  if any_updated then
    sync_to_storage(self)

    ErrorHandler.debug_log("PlayerFavorites GPS coordinates updated - notifying observers", {
      player_index = self.player_index,
      old_gps = old_gps,
      new_gps = new_gps
    })

    -- Notify observers of GPS update
    notify_observers_safe("favorites_gps_updated", {
      player_index = self.player_index,
      old_gps = old_gps,
      new_gps = new_gps
    })
    
    -- CRITICAL: Trigger cache_updated to rebuild favorites bar
    notify_observers_safe("cache_updated", {
      type = "favorites_gps_updated",
      player_index = self.player_index,
      old_gps = old_gps,
      new_gps = new_gps
    })
  end

  return any_updated
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

  for _, player in pairs(game.players) do
    ---@cast player LuaPlayer
    if player and player.valid and player.index ~= acting_player_index then
      local favorites = PlayerFavorites.new(player)
      local was_updated = favorites:update_gps_coordinates(old_gps, new_gps)

      if was_updated then
        table.insert(affected_players, player)
      end
    end
  end

  return affected_players
end

--- Returns the number of available (blank) favorite slots
function PlayerFavorites:available_slots()
  local count = 0
  for i = 1, #self.favorites do
    if FavoriteUtils.is_blank_favorite(self.favorites[i]) then
      count = count + 1
    end
  end
  return count
end

return PlayerFavorites
