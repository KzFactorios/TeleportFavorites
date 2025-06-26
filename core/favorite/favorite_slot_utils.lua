-- favorite_slot_utils.lua
-- Centralized helpers for favorite slot logic (lock, drag, etc.)

local FavoriteSlotUtils = {}

--- Returns true if the favorite is locked
---@param fav table
---@return boolean
function FavoriteSlotUtils.is_locked_favorite(fav)
  return fav and fav.locked == true
end

--- Returns true if the favorite can be dragged
---@param fav table
---@return boolean
function FavoriteSlotUtils.can_start_drag(fav)
  return fav and not FavoriteSlotUtils.is_blank_favorite(fav) and not FavoriteSlotUtils.is_locked_favorite(fav)
end

--- Returns true if the favorite is blank (no GPS or text)
---@param fav table
---@return boolean
function FavoriteSlotUtils.is_blank_favorite(fav)
  return not fav or (not fav.gps and not fav.text)
end

return FavoriteSlotUtils
