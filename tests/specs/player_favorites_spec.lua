require("test_bootstrap")
require("mocks.factorio_test_env")

-- Mock all dependencies that PlayerFavorites requires
package.loaded["constants"] = {
    MAX_FAVORITE_SLOTS = 10,
    MAX_TELEPORT_HISTORY_SIZE = 5,
    settings = {},
    commands = {}
}

package.loaded["core.favorite.favorite"] = {
    new = function(gps, locked, tag) return {gps = gps, locked = locked or false, tag = tag} end,
    get_blank_favorite = function() return {gps = nil, locked = false, tag = nil} end,
    copy = function(fav) return fav and {gps = fav.gps, locked = fav.locked, tag = fav.tag} or nil end,
    equals = function(a, b) return a and b and a.gps == b.gps end
}

package.loaded["core.cache.cache"] = {
    get_player_data = function() return {surfaces = {}} end,
    get_player_favorites = function() return {} end,
    set_player_favorites = function() end,
    notify_observers_safe = function() end
}

package.loaded["core.utils.error_handler"] = {
    handle_error = function() end,
    debug_log = function() end
}

-- Mock GuiObserver
_G.GuiObserver = {
    notify = function() end,
    register = function() end
}

describe("PlayerFavorites module", function()
    it("should load PlayerFavorites module without errors", function()
        local success, err = pcall(function()
            local PlayerFavorites = require("core.favorite.player_favorites")
            assert(PlayerFavorites ~= nil, "PlayerFavorites module should load")
            assert(type(PlayerFavorites) == "table", "PlayerFavorites should be a table")
        end)
        assert(success, "PlayerFavorites module should load without errors: " .. tostring(err))
    end)
    
    it("should expose expected PlayerFavorites API methods", function()
        local success, err = pcall(function()
            local PlayerFavorites = require("core.favorite.player_favorites")
            
            -- Check that key API methods exist
            assert(type(PlayerFavorites.new) == "function", "PlayerFavorites.new should be a function")
            assert(type(PlayerFavorites.get_favorite_by_gps) == "function", "get_favorite_by_gps should be a function")
            assert(type(PlayerFavorites.add_favorite) == "function", "add_favorite should be a function")
            assert(type(PlayerFavorites.remove_favorite) == "function", "remove_favorite should be a function")
            assert(type(PlayerFavorites.move_favorite) == "function", "move_favorite should be a function")
            assert(type(PlayerFavorites.toggle_favorite_lock) == "function", "toggle_favorite_lock should be a function")
        end)
        assert(success, "PlayerFavorites API methods should exist: " .. tostring(err))
    end)
    
    it("should create PlayerFavorites instance without errors", function()
        local success, err = pcall(function()
            -- Mock a basic player object
            local mock_player = {
                index = 1,
                name = "TestPlayer",
                valid = true,
                surface = { index = 1 }
            }
            
            local PlayerFavorites = require("core.favorite.player_favorites")
            local instance = PlayerFavorites.new(mock_player)
            
            assert(instance ~= nil, "PlayerFavorites instance should be created")
            assert(type(instance) == "table", "PlayerFavorites instance should be a table")
        end)
        assert(success, "PlayerFavorites instance creation should work: " .. tostring(err))
    end)
    
    it("should handle basic operations without errors", function()
        local success, err = pcall(function()
            local mock_player = {
                index = 1,
                name = "TestPlayer", 
                valid = true,
                surface = { index = 1 }
            }
            
            local PlayerFavorites = require("core.favorite.player_favorites")
            local instance = PlayerFavorites.new(mock_player)
            
            -- Test basic operations that should not crash
            local favorite = instance:get_favorite_by_gps("test_gps")
            -- favorite can be nil, that's expected
            
            -- Test method existence on instance
            assert(type(instance.add_favorite) == "function", "instance should have add_favorite method")
            assert(type(instance.remove_favorite) == "function", "instance should have remove_favorite method")
            assert(type(instance.move_favorite) == "function", "instance should have move_favorite method")
        end)
        assert(success, "PlayerFavorites basic operations should work: " .. tostring(err))
    end)
end)
