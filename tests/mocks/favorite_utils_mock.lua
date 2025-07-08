-- tests/mocks/favorite_utils_mock.lua
-- Provides a robust global FavoriteUtils mock for tests

_G.FavoriteUtils = {
    is_blank_favorite = function(fav)
        return not fav or not fav.gps or fav.gps == ""
    end,
    get_blank_favorite = function()
        return { gps = "", locked = false }
    end,
    new = function(gps)
        return { gps = gps, locked = false }
    end
}

return _G.FavoriteUtils
