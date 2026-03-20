-- core/favorite/favorite_rehydration.lua
-- TeleportFavorites Factorio Mod
-- Handles runtime rehydration of favorites by restoring chart_tag references from cache, avoiding circular dependencies.

local Cache = require("core.cache.cache")
local FavoriteUtils = require("core.favorite.favorite_utils")

local FavoriteRehydration = {}

--- Rehydrate a favorite's tag and chart_tag from GPS using the runtime cache
---@param player LuaPlayer
---@param fav table Favorite
---@return table Favorite
function FavoriteRehydration.rehydrate_favorite_at_runtime(player, fav)
  if not player then return FavoriteUtils.get_blank_favorite() end
  if not fav or type(fav) ~= "table" or not fav.gps or fav.gps == "" or FavoriteUtils.is_blank_favorite(fav) then
    return FavoriteUtils.get_blank_favorite()
  end

  local tag = Cache.get_tag_by_gps(player, fav.gps)
  
  local locked = fav.locked or false
  local new_fav = FavoriteUtils.new(fav.gps, locked, tag)
  
  -- If we have a tag but no chart_tag, try to get one from runtime cache
  if tag and not tag.chart_tag then
    local chart_tag = Cache.Lookups and Cache.Lookups.get_chart_tag_by_gps(fav.gps)
    if chart_tag and chart_tag.valid then
      tag.chart_tag = chart_tag
    end
  end

  return new_fav
end

return FavoriteRehydration
