-- tests/mocks/favorite_utils_mock.lua
-- Provides a robust global FavoriteUtils mock for tests

_G.FavoriteUtils = {
    is_blank_favorite = function(fav)
        return not fav or not fav.gps or fav.gps == "" or fav.gps == "1000000.1000000.1"
    end,
    get_blank_favorite = function()
        return { gps = "1000000.1000000.1", locked = false }
    end,
    normalize_blank_favorite = function(fav)
        if fav and (fav.gps == nil or fav.gps == "") then
            fav.gps = "1000000.1000000.1"
        end
        return fav
    end,
    new = function(gps)
        return { gps = gps, locked = false }
    end
}

return _G.FavoriteUtils
