-- core/utils/favorite_utils.lua
-- Utilities for working with favorites that require runtime/game context (e.g., cache lookups)

local Cache = require("core.cache.cache")
local FavoriteUtils = require("core.favorite.favorite")

local FavoriteRuntimeUtils = {}

--- Rehydrate a favorite's tag and chart_tag from GPS using the runtime cache
---@param fav table Favorite
---@return table Favorite (with tag/chart_tag fields populated if possible)
function FavoriteRuntimeUtils.rehydrate_favorite(fav)
  if not fav or type(fav) ~= "table" or not fav.gps or fav.gps == "" then return FavoriteUtils.get_blank_favorite() end
  local tag = Cache.get_tag_by_gps(fav.gps)
  local locked = fav.locked or false
  local new_fav = FavoriteUtils.new(fav.gps, locked, tag)
  if tag and not tag.chart_tag then
    local chart_tag = Cache.Lookups.get_chart_tag_by_gps(fav.gps)
    if chart_tag and chart_tag.valid then
      tag.chart_tag = chart_tag
    end
  end
  return new_fav
end

return FavoriteRuntimeUtils
