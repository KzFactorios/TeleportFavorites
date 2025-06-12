---@diagnostic disable: undefined-global
--[[
core/favorite/player_favorites.lua
TeleportFavorites Factorio Mod
-----------------------------
PlayerFavorites class: manages a collection of favorites for a specific player.

- Provides a comprehensive interface for favorite collection operations
- Handles slot management, lookup, persistence, and favorite manipulation
- All persistent data is managed via the Cache module and is surface-aware
- Used for favorites bar, tag editor, and all player favorite operations

Features:
---------
- Add/remove favorites with automatic slot management
- Reorder favorites with drag-and-drop support
- Lock/unlock favorites to prevent accidental changes
- Find favorites by GPS or slot index
- Swap and move operations for slot organization
- Automatic tag synchronization and cleanup
- Comprehensive validation and error handling

Notes:
------
- All slot management is 1-based and respects MAX_FAVORITE_SLOTS from Constants
- Blank slots are always filled with Favorite.get_blank_favorite()
- All persistent data is surface-aware and managed via Cache
- Operations maintain consistency between instance state and storage
--]]

local Constants = require("constants")
local FavoriteUtils = require("core.favorite.favorite")
local Helpers = require("core.utils.helpers_suite")
local basic_helpers = require("core.utils.basic_helpers")
local Cache = require("core.cache.cache")

-- Observer Pattern Integration
local function notify_observers_safe(event_type, data)
  -- Safe notification that handles module load order
  local success, gui_observer = pcall(require, "core.pattern.gui_observer")
  if success and gui_observer.GuiEventBus then
    gui_observer.GuiEventBus.notify(event_type, data)
  end
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
  else -- action == "remove"
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

--- Get a favorite by slot index
---@param slot_idx number
---@return Favorite|nil
function PlayerFavorites:get_favorite_by_slot(slot_idx)
  if not is_valid_slot(slot_idx) then return nil end
  return self.favorites[slot_idx]
end

--- Get all favorites as a copy
---@return Favorite[]
function PlayerFavorites:get_all_favorites()
  local copy = {}
  for i, fav in ipairs(self.favorites) do
    copy[i] = fav
  end
  return copy
end

--- Set the entire favorites collection
---@param new_favorites Favorite[]
---@return boolean success
function PlayerFavorites:set_favorites(new_favorites)
  if type(new_favorites) ~= "table" then return false end

  -- Validate and pad array to correct size
  local validated_favorites = {}
  for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
    if new_favorites[i] and type(new_favorites[i]) == "table" then
      validated_favorites[i] = new_favorites[i]
    else
      validated_favorites[i] = FavoriteUtils.get_blank_favorite()
    end
  end

  self.favorites = validated_favorites
  sync_to_storage(self)
  return true
end

--- Add a favorite to the first available slot
---@param gps string
---@return Favorite|nil, string|nil error_message
function PlayerFavorites:add_favorite(gps)
  if not gps or type(gps) ~= "string" or gps == "" then
    return nil, "Invalid GPS string"
  end

  -- Check if already exists
  local existing_fav, existing_slot = self:get_favorite_by_gps(gps)
  if existing_fav then return existing_fav, nil end

  -- Find first available slot
  local slot_idx = nil
  for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
    if FavoriteUtils.is_blank_favorite(self.favorites[i]) then
      slot_idx = i
      break
    end
  end

  if not slot_idx then
    return nil, "No available slots (maximum " .. Constants.settings.MAX_FAVORITE_SLOTS .. " favorites)"
  end

  -- Get or create tag
  local existing_tag = Cache.get_tag_by_gps(gps)

  -- Create new favorite
  local new_favorite = FavoriteUtils.new(gps, false, existing_tag)
  if not new_favorite then
    return nil, "Failed to create favorite"
  end

  -- Update tag's faved_by_players list
  if existing_tag then
    update_tag_favorites(existing_tag, self.player_index, "add")
  end
  -- Update favorites and storage
  self.favorites[slot_idx] = new_favorite
  sync_to_storage(self)

  -- Notify observers
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

  -- Update tag's faved_by_players list
  local existing_tag = Cache.get_tag_by_gps(gps)
  if existing_tag then
    update_tag_favorites(existing_tag, self.player_index, "remove")
  end
  -- Replace with blank favorite
  self.favorites[slot_idx] = FavoriteUtils.get_blank_favorite()
  sync_to_storage(self)

  -- Notify observers
  notify_observers_safe("favorite_removed", {
    player_index = self.player_index,
    gps = gps,
    slot_index = slot_idx
  })

  return true, nil
end

--- Remove a favorite by slot index
---@param slot_idx number
---@return boolean success, string|nil error_message
function PlayerFavorites:remove_favorite_by_slot(slot_idx)
  if not is_valid_slot(slot_idx) then
    return false, "Invalid slot index"
  end

  local fav = self.favorites[slot_idx]
  if not fav or FavoriteUtils.is_blank_favorite(fav) then
    return true, nil -- Already blank
  end

  return self:remove_favorite(fav.gps)
end

--- Swap two favorites by slot indices
---@param slot_a number
---@param slot_b number
---@return boolean success, string|nil error_message
function PlayerFavorites:swap_slots(slot_a, slot_b)
  if not is_valid_slot(slot_a) or not is_valid_slot(slot_b) then
    return false, "Invalid slot indices"
  end

  if slot_a == slot_b then return true, nil end

  local fav_a = self.favorites[slot_a]
  local fav_b = self.favorites[slot_b]

  -- Check if either is locked
  if (fav_a and fav_a.locked) or (fav_b and fav_b.locked) then
    return false, "Cannot swap locked favorites"
  end

  -- Perform swap
  self.favorites[slot_a] = fav_b
  self.favorites[slot_b] = fav_a
  sync_to_storage(self)

  return true, nil
end

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

  -- Move favorite and shift others
  local moved_fav = table.remove(self.favorites, math.floor(from_slot))
  table.insert(self.favorites, math.floor(to_slot), moved_fav)

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

--- Check if favorites collection is full
---@return boolean
function PlayerFavorites:is_full()
  for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
    if FavoriteUtils.is_blank_favorite(self.favorites[i]) then
      return false
    end
  end
  return true
end

--- Get count of non-blank favorites
---@return number
function PlayerFavorites:get_favorite_count()
  local count = 0
  for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
    if not FavoriteUtils.is_blank_favorite(self.favorites[i]) then
      count = count + 1
    end
  end
  return count
end

--- Get first available slot index
---@return number|nil
function PlayerFavorites:get_first_empty_slot()
  for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
    if FavoriteUtils.is_blank_favorite(self.favorites[i]) then
      return i
    end
  end
  return nil
end

--- Compact favorites by removing gaps (blank slots)
---@return boolean success
function PlayerFavorites:compact()
  local compacted = {}
  local index = 1

  -- Collect all non-blank favorites
  for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
    local fav = self.favorites[i]
    if not FavoriteUtils.is_blank_favorite(fav) then
      compacted[index] = fav
      index = index + 1
    end
  end

  -- Fill remaining slots with blanks
  for i = index, Constants.settings.MAX_FAVORITE_SLOTS do
    compacted[i] = FavoriteUtils.get_blank_favorite()
  end

  self.favorites = compacted
  sync_to_storage(self)
  return true
end

--- Validate the integrity of the favorites collection
---@return boolean is_valid, string[] issues
function PlayerFavorites:validate()
  local issues = {}
  local is_valid = true

  -- Check array size
  if #self.favorites ~= Constants.settings.MAX_FAVORITE_SLOTS then
    table.insert(issues,
      "Favorites array has incorrect size: " ..
      #self.favorites .. " (expected " .. Constants.settings.MAX_FAVORITE_SLOTS .. ")")
    is_valid = false
  end

  -- Check for duplicate GPS
  local seen_gps = {}
  for i, fav in ipairs(self.favorites) do
    if fav and not FavoriteUtils.is_blank_favorite(fav) then
      if seen_gps[fav.gps] then
        table.insert(issues, "Duplicate GPS found at slots " .. seen_gps[fav.gps] .. " and " .. i .. ": " .. fav.gps)
        is_valid = false
      else
        seen_gps[fav.gps] = i
      end
    end
  end

  return is_valid, issues
end

return PlayerFavorites
