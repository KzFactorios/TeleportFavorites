-- core/favorite/favorite_utils.lua
-- TeleportFavorites Factorio Mod
-- Favorite class for representing a player's favorite teleport location, with GPS, locked state, and tag helpers.

local Deps = require("base_deps")
local BasicHelpers, Constants = Deps.BasicHelpers, Deps.Constants

---@class Favorite
---@field gps string GPS coordinates in 'xxx.yyy.s' format
---@field locked boolean Whether the favorite is locked (prevents removal/editing)
---@field tag table? Optional tag table for tooltip formatting and richer UI


local FavoriteUtils = {}


---@param gps string?
---@param locked boolean?
---@param tag table?
---@return Favorite
function FavoriteUtils.new(gps, locked, tag)
  return {
    gps = gps or (Constants.settings.BLANK_GPS --[[@as string]]),
    locked = locked or false,
    tag = tag or nil
  }
end

---@param fav Favorite?
---@return boolean
function FavoriteUtils.is_blank_favorite(fav)
  if type(fav) ~= "table" then return false end
  if next(fav) == nil then return true end
  return (fav.gps == "" or fav.gps == nil or fav.gps == (Constants.settings.BLANK_GPS --[[@as string]]))
    and (fav.locked == false or fav.locked == nil)
end

---@return Favorite
function FavoriteUtils.get_blank_favorite()
  return FavoriteUtils.new((Constants.settings.BLANK_GPS --[[@as string]]), false, nil)
end

---@param fav Favorite
---@return Favorite?
function FavoriteUtils.copy(fav)
  if type(fav) ~= "table" then return nil end
  local copy = FavoriteUtils.new(fav.gps, fav.locked, fav.tag and BasicHelpers.deep_copy(fav.tag) or nil)
  for k, v in pairs(fav) do
    if copy[k] == nil then copy[k] = v end
  end
  return copy
end

--- Whether two stored favorites represent the same bar cell visuals (gps + blank + lock).
--- Used to detect which slot indices need GUI refresh after reorder.
---@param a Favorite?
---@param b Favorite?
---@return boolean
function FavoriteUtils.same_visual_identity(a, b)
  local ab = FavoriteUtils.is_blank_favorite(a)
  local bb = FavoriteUtils.is_blank_favorite(b)
  if ab and bb then return true end
  if ab or bb then return false end
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  return (a.gps == b.gps) and ((a.locked or false) == (b.locked or false))
end

--- Shallow copy of favorite + tag table for reorder paths (avoids deep_copy of tag per slot).
---@param fav Favorite?
---@return Favorite?
function FavoriteUtils.copy_for_reorder(fav)
  if type(fav) ~= "table" then return nil end
  local tag = fav.tag
  local tag_copy = nil
  if type(tag) == "table" then
    tag_copy = {}
    for k, v in pairs(tag) do
      tag_copy[k] = v
    end
  end
  local copy = FavoriteUtils.new(fav.gps, fav.locked, tag_copy)
  for k, v in pairs(fav) do
    if copy[k] == nil then copy[k] = v end
  end
  return copy
end

return FavoriteUtils
