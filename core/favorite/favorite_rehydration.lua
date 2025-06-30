--[[
core/favorite/favorite_rehydration.lua
TeleportFavorites Factorio Mod
-----------------------------
Handles favorite rehydration logic separately to avoid circular dependencies.

This module provides the runtime rehydration of favorites by restoring chart_tag
references from the cache system using proper lazy loading.
]]

local Cache = require("core.cache.cache")
local FavoriteUtils = require("core.favorite.favorite")

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

  -- Safely get tag, return blank favorite if any errors occur
  local tag = nil
  local tag_success, tag_error = pcall(function()
    tag = Cache.get_tag_by_gps(player, fav.gps)
  end)
  
  if not tag_success then
    -- Cache.get_tag_by_gps failed (likely due to invalid chart_tag), return blank favorite
    return FavoriteUtils.get_blank_favorite()
  end
  
  local locked = fav.locked or false
  local new_fav = FavoriteUtils.new(fav.gps, locked, tag)
  
  -- If we have a tag but no chart_tag, try to get one safely
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
      -- Chart tag lookup failed, but we can still return the favorite without chart_tag
      -- The favorites bar will handle this gracefully
    end
  end

  return new_fav
end

return FavoriteRehydration
