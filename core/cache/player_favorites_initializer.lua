-- core/cache/player_favorites_initializer.lua
-- Helper to initialize a player's favorites array without causing circular require issues

local Constants = require("constants")

local PlayerFavoritesInitializer = {}

--- Return a blank favorite (gps/locked only, no tag)
local function get_blank_favorite()
  return {
    gps = Constants.settings.BLANK_GPS,
    locked = false
  }
end

--- Initialize the favorites array for a player (used by cache.lua)
---@param pfaves table[]
---@return table[]
function PlayerFavoritesInitializer.init_player_favorites(pfaves)
  pfaves = pfaves or {}
  for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
    local fav = pfaves[i]
    if not fav or type(fav) ~= "table" then
      fav = get_blank_favorite()
    end
    if fav.gps == nil then fav.gps = Constants.settings.BLANK_GPS end
    if fav.locked == nil then fav.locked = false end
    pfaves[i] = fav
  end
  return pfaves
end

return PlayerFavoritesInitializer
