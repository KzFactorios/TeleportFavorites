local Cache = require("core.cache.cache")
local FavoriteUtils = require("core.favorite.favorite_utils")

local FavoriteRehydration = {}

---@param player LuaPlayer
---@param fav table Favorite
---@return table Favorite
function FavoriteRehydration.rehydrate_favorite_at_runtime(player, fav)
  if not player then return FavoriteUtils.get_blank_favorite() end
  if not fav or type(fav) ~= "table" or not fav.gps or fav.gps == "" or FavoriteUtils.is_blank_favorite(fav) then
    return FavoriteUtils.get_blank_favorite()
  end

  local tag = nil
  local tag_success, tag_error = pcall(function()
    tag = Cache.get_tag_by_gps(player, fav.gps)
  end)

  if not tag_success then
    return FavoriteUtils.get_blank_favorite()
  end

  local locked = fav.locked or false
  local new_fav = FavoriteUtils.new(fav.gps, locked, tag)

  if tag and not tag.chart_tag then
    local chart_tag_success, chart_tag_error = pcall(function()
      local chart_tag = Cache.Lookups.get_chart_tag_by_gps(fav.gps)
      if chart_tag then
        local valid_check_success, is_valid = pcall(function() return chart_tag.valid end)
        if valid_check_success and is_valid then
          tag.chart_tag = chart_tag
        end
      end
    end)

    if not chart_tag_success then
    end
  end

  return new_fav
end

return FavoriteRehydration
