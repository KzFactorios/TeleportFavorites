---@class PlayerFavorites
-- Wrapper for a collection of favorites for a specific player.
-- Handles slot management, persistence, and favorite manipulation.

local Constants = require("constants")
local Favorite = require("core.favorite.favorite")
local Cache = require("core.cache.cache")

local PlayerFavorites = {}
PlayerFavorites.__index = PlayerFavorites

local blank_favorite = Favorite.blank_favorite

--- Constructor
-- @param player LuaPlayer
function PlayerFavorites:new(player)
    local obj = setmetatable({}, self)
    obj.player = player
    obj.player_index = player.index
    obj.surface_index = player.surface.index
    -- Ensure persistent storage exists using Cache
    Cache.init()
    local players = Cache.get("players") or {}
    players[obj.player_index] = players[obj.player_index] or {}
    players[obj.player_index].favorites = players[obj.player_index].favorites or {}
    players[obj.player_index].favorites[obj.surface_index] = players[obj.player_index].favorites[obj.surface_index] or {}
    obj.favorites = players[obj.player_index].favorites[obj.surface_index]
    -- Initialize slots if empty
    if #obj.favorites == 0 then
        for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
            obj.favorites[i] = Favorite.get_blank_favorite()
        end
    end
    Cache.set("players", players)
    return obj
end

--- Add a favorite GPS to the first available slot
-- @param gps string
-- @return boolean success
function PlayerFavorites:add_favorite(gps)
    for i, fav in ipairs(self.favorites) do
        if fav.gps == "" then
            fav.gps = gps
            fav.locked = false
            return true
        end
    end
    return false -- No open slot
end

--- Remove a favorite by GPS
-- @param gps string
function PlayerFavorites:remove_favorite(gps)
    for i, fav in ipairs(self.favorites) do
        if fav.gps == gps then
            fav = Favorite.get_blank_favorite()
            return
        end
    end
end

--- Swap two favorite slots by index
-- @param idx1 number
-- @param idx2 number
function PlayerFavorites:swap_slots(idx1, idx2)
    self.favorites[idx1], self.favorites[idx2] = self.favorites[idx2], self.favorites[idx1]
end

--- Get the list of all favorite GPS strings
function PlayerFavorites:get_all_gps()
    local list = {}
    for i, fav in ipairs(self.favorites) do
        table.insert(list, fav.gps)
    end
    return list
end

--- Cascade favorites up from a given index (pushes elements up, must be room, locked slots cannot be moved)
-- @param from_idx number Index to start cascading from (1-based)
-- @return boolean success True if cascade succeeded, false otherwise
function PlayerFavorites:cascade_slots_up(from_idx)
    local max_slots = Constants.settings.MAX_FAVORITE_SLOTS
    -- Find the first empty slot above from_idx
    local empty_idx = nil
    for i = from_idx - 1, 1, -1 do
        if self.favorites[i].gps == "" then
            empty_idx = i
            break
        end
    end
    if not empty_idx then return false end -- No room to cascade up
    -- Cascade up, skipping locked slots
    for i = empty_idx, from_idx - 1 do
        if self.favorites[i + 1].locked then
            return false -- Cannot move locked slot
        end
        self.favorites[i].gps = self.favorites[i + 1].gps
        self.favorites[i].locked = self.favorites[i + 1].locked
        -- Clear the slot we just copied from
        if i + 1 == from_idx then
            self.favorites[i + 1] = Favorite.get_blank_favorite()
        end
    end
    return true
end

--- Cascade favorites down from a given index (pushes elements down, must be room, locked slots cannot be moved)
-- @param from_idx number Index to start cascading from (1-based)
-- @return boolean success True if cascade succeeded, false otherwise
function PlayerFavorites:cascade_slots_down(from_idx)
    local max_slots = Constants.settings.MAX_FAVORITE_SLOTS
    -- Find the first empty slot below from_idx
    local empty_idx = nil
    for i = from_idx + 1, max_slots do
        if self.favorites[i].gps == "" then
            empty_idx = i
            break
        end
    end
    if not empty_idx then return false end -- No room to cascade down
    -- Cascade down, skipping locked slots
    for i = empty_idx, from_idx + 1, -1 do
        if self.favorites[i - 1].locked then
            return false -- Cannot move locked slot
        end
        self.favorites[i].gps = self.favorites[i - 1].gps
        self.favorites[i].locked = self.favorites[i - 1].locked
        -- Clear the slot we just copied from
        if i - 1 == from_idx then
            self.favorites[i - 1] = Favorite.get_blank_favorite()
        end
    end
    return true
end

return PlayerFavorites
