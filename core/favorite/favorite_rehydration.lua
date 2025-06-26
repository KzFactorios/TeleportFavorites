--[[
core/favorite/favorite_rehydration.lua
TeleportFavorites Factorio Mod
-----------------------------
Handles favorite rehydration logic separately to avoid circular dependencies.

This module provides the runtime rehydration of favorites by restoring chart_tag
references from the cache system using proper lazy loading.
]]

local Cache = require("core.cache.cache")
local Logger = require("core.utils.enhanced_error_handler")
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

  local tag = Cache.get_tag_by_gps(player, fav.gps)
  local locked = fav.locked or false
  local new_fav = FavoriteUtils.new(fav.gps, locked, tag)
  
  Logger.debug_log("[FAVE_BAR] Rehydrate step 1 - got tag from cache", {
    gps = fav.gps,
    tag_present = tag ~= nil,
    tag_has_chart_tag = tag and tag.chart_tag ~= nil
  })
  
  if tag and not tag.chart_tag then
    local chart_tag = Cache.Lookups.get_chart_tag_by_gps(fav.gps)
    Logger.debug_log("[FAVE_BAR] Rehydrate step 2 - lookup chart_tag", {
      gps = fav.gps,
      chart_tag_found = chart_tag ~= nil,
      chart_tag_valid = chart_tag and chart_tag.valid or false
    })
    if chart_tag and chart_tag.valid then
      tag.chart_tag = chart_tag
      Logger.debug_log("[FAVE_BAR] Rehydrate step 3 - attached chart_tag to tag", {
        gps = fav.gps,
        chart_tag_has_icon = chart_tag.icon ~= nil
      })
    end
  end

  local icon_info = nil
  if tag and tag.chart_tag and tag.chart_tag.icon then
    local icon = tag.chart_tag.icon
    icon_info = (icon.type or "<no type>") .. "/" .. (icon.name or "<no name>")
  end
  Logger.debug_log("[FAVE_BAR] Rehydrate favorite", {
    gps = fav.gps,
    tag_present = tag ~= nil,
    chart_tag_present = tag and tag.chart_tag ~= nil,
    icon_present = tag and tag.chart_tag and tag.chart_tag.icon ~= nil,
    icon_info = icon_info
  })

  return new_fav
end

return FavoriteRehydration
