-- core/utils/favorites_helpers.lua
-- Utility for initializing and normalizing player favorites arrays for TeleportFavorites mod.
-- Standalone to avoid circular dependencies between Cache, PlayerFavorites, and Favorite.

local Constants = require("constants")

--- Initialize and return a player's favorites array, and the access array keyed by gps,
--- filling blanks and ensuring structure.
---@param pdata table -- represents player_data.surfaces[player.surface.index]
---@return Favorite[]
local function init_player_favorites(pdata)
  pdata.favorites = pdata.favorites or {}
  local pfaves = pdata.favorites or {}

  for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
    if not pfaves[i] or type(pfaves[i]) ~= "table" then
      pfaves[i] = Constants.get_blank_favorite()
    end
    pfaves[i].gps = pfaves[i].gps or ""
    pfaves[i].locked = pfaves[i].locked or false
  end

  return pfaves
end

return {
  init_player_favorites = init_player_favorites,
}
