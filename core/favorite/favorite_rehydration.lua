-- core/favorite/favorite_rehydration.lua
-- TeleportFavorites Factorio Mod
-- Handles runtime rehydration of favorites by restoring chart_tag references from cache, avoiding circular dependencies.

local Cache = require("core.cache.cache")
local ErrorHandler = require("core.utils.error_handler")
local FavoriteUtils = require("core.favorite.favorite_utils")

local FavoriteRehydration = {}

--- Rehydrate a favorite's tag and chart_tag from GPS using the runtime cache
---@param player LuaPlayer
---@param fav table Favorite
---@return table Favorite
function FavoriteRehydration.rehydrate_favorite_at_runtime(player, fav)
  local tick = game and game.tick or 0
  
  if not player then return FavoriteUtils.get_blank_favorite() end
  if not fav or type(fav) ~= "table" or not fav.gps or fav.gps == "" or FavoriteUtils.is_blank_favorite(fav) then
    return FavoriteUtils.get_blank_favorite()
  end

  local t0 = tick
  local tag = Cache.get_tag_by_gps(player, fav.gps)
  local t1 = game and game.tick or 0
  
  if t1 > t0 then
    ErrorHandler.debug_log("[SPIKE_DEBUG] rehydrate_favorite: Cache.get_tag_by_gps took multiple ticks", { duration = t1 - t0, gps = fav.gps })
  end
  
  local locked = fav.locked or false
  local new_fav = FavoriteUtils.new(fav.gps, locked, tag)
  -- chart_tag is already attached transiently by Cache.get_tag_by_gps()
  -- Do NOT write chart_tag userdata back to storage-backed tag objects (causes multiplayer desyncs)
  return new_fav
end

return FavoriteRehydration
