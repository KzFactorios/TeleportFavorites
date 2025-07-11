-- Debug script to test PlayerFavorites module loading
print("=== Testing PlayerFavorites Module Loading ===")

-- Setup minimal environment
_G.storage = {}
_G.global = {}

-- Mock required modules
_G.Constants = { settings = { MAX_FAVORITE_SLOTS = 10 } }

-- Mock GuiObserver
_G.GuiObserver = {
    GuiEventBus = {
        notify = function(event_type, data)
            print("Observer notification:", event_type)
        end
    }
}

-- Mock cache module
package.loaded["core.cache.cache"] = {
    get_player_favorites = function(player) return {} end,
    get_tag_by_gps = function(player, gps) return nil end,
    sanitize_for_storage = function(tag, exclude) return tag end
}

-- Mock FavoriteUtils
package.loaded["core.favorite.favorite"] = {
    new = function(gps, locked, tag) return {gps = gps, locked = locked, tag = tag} end,
    get_blank_favorite = function() return {gps = "", locked = false} end,
    is_blank_favorite = function(fav) return fav and fav.gps == "" end,
    toggle_locked = function(fav) fav.locked = not fav.locked end
}

-- Mock ErrorHandler
package.loaded["core.utils.error_handler"] = {
    debug_log = function(msg, data) print("ErrorHandler:", msg) end
}

-- Mock gui_observer
package.loaded["core.events.gui_observer"] = _G.GuiObserver

print("Loading PlayerFavorites module...")
local PlayerFavorites = require("core.favorite.player_favorites")

print("PlayerFavorites type:", type(PlayerFavorites))
print("PlayerFavorites.new:", type(PlayerFavorites.new))
print("PlayerFavorites.add_favorite:", type(PlayerFavorites.add_favorite))
print("PlayerFavorites.__index:", PlayerFavorites.__index)

-- Test creating an object
local mock_player = {
    index = 1,
    valid = true,
    surface = { index = 1 }
}

print("\nCreating PlayerFavorites instance...")
local pf = PlayerFavorites.new(mock_player)
print("Instance type:", type(pf))
print("Instance add_favorite method:", type(pf.add_favorite))
print("Instance metatable:", getmetatable(pf))

print("\n=== Test Complete ===")
