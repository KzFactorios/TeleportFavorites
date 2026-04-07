-- core/favorite/favorite_rehydration.lua
-- TeleportFavorites Factorio Mod
-- Handles runtime rehydration of favorites by restoring chart_tag references from cache, avoiding circular dependencies.

local Cache = require("core.cache.cache")
local FavoriteUtils = require("core.favorite.favorite_utils")
local ErrorHandler = require("core.utils.error_handler")

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

  if ErrorHandler and ErrorHandler.debug_log then
    ErrorHandler.debug_log("[DEEP][rehydrate_favorite_at_runtime] entry", {
      player = player and player.name or "<nil>",
      fav_gps = fav and fav.gps or "<nil>",
      fav_full = fav
    })
  end
  local tag = Cache.get_tag_by_gps(player, fav.gps)
  if ErrorHandler and ErrorHandler.debug_log then
    ErrorHandler.debug_log("[DEEP][rehydrate_favorite_at_runtime] after get_tag_by_gps", {
      player = player and player.name or "<nil>",
      fav_gps = fav and fav.gps or "<nil>",
      tag_found = tag ~= nil,
      tag_gps = tag and tag.gps or "<nil>",
      tag_full = tag
    })
  end
  local locked = fav.locked or false
  local new_fav = FavoriteUtils.new(fav.gps, locked, tag)
  -- chart_tag is already attached transiently by Cache.get_tag_by_gps()
  -- Do NOT write chart_tag userdata back to storage-backed tag objects (causes multiplayer desyncs)
  return new_fav
end

return FavoriteRehydration
