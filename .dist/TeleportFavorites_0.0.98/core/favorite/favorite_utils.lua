local Deps = require("core.base_deps_barrel")
local BasicHelpers, Constants = Deps.BasicHelpers, Deps.Constants
local FavoriteUtils = {}
function FavoriteUtils.new(gps, locked, tag)
  return {
    gps = gps or (Constants.settings.BLANK_GPS ),
    locked = locked or false,
    tag = tag or nil
  }
end
function FavoriteUtils.is_blank_favorite(fav)
  if type(fav) ~= "table" then return false end
  if next(fav) == nil then return true end
  return (fav.gps == "" or fav.gps == nil or fav.gps == (Constants.settings.BLANK_GPS ))
    and (fav.locked == false or fav.locked == nil)
end
function FavoriteUtils.get_blank_favorite()
  return FavoriteUtils.new((Constants.settings.BLANK_GPS ), false, nil)
end
function FavoriteUtils.copy(fav)
  if type(fav) ~= "table" then return nil end
  local copy = FavoriteUtils.new(fav.gps, fav.locked, fav.tag and BasicHelpers.deep_copy(fav.tag) or nil)
  for k, v in pairs(fav) do
    if copy[k] == nil then copy[k] = v end
  end
  return copy
end
function FavoriteUtils.same_visual_identity(a, b)
  local ab = FavoriteUtils.is_blank_favorite(a)
  local bb = FavoriteUtils.is_blank_favorite(b)
  if ab and bb then return true end
  if ab or bb then return false end
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  return (a.gps == b.gps) and ((a.locked or false) == (b.locked or false))
end
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
