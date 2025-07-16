require("test_bootstrap")
require("mocks.factorio_test_env")

-- Mock all dependencies that PlayerFavorites requires
package.loaded["constants"] = {
    MAX_FAVORITE_SLOTS = 10,
    MAX_TELEPORT_HISTORY_SIZE = 5,
    settings = {
        MAX_FAVORITE_SLOTS = 10,
        BLANK_GPS = "1000000.1000000.1"
    },
    commands = {}
}

package.loaded["core.favorite.favorite"] = {
    new = function(gps, locked, tag) return {gps = gps, locked = locked or false, tag = tag} end,
    get_blank_favorite = function() return {gps = "1000000.1000000.1", locked = false, tag = nil} end,
    copy = function(fav) return fav and {gps = fav.gps, locked = fav.locked, tag = fav.tag} or nil end,
    equals = function(a, b) return a and b and a.gps == b.gps end,
    is_blank_favorite = function(fav) return fav and fav.gps == "1000000.1000000.1" end
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

-- Mock DragDropUtils with the new API
package.loaded["core.utils.drag_drop_utils"] = {
    reorder_slots = function(slots, from_slot, to_slot)
        -- Simple mock implementation for testing
        if from_slot == to_slot then
            return slots, false, "Source and destination slots are the same"
        end
        if from_slot < 1 or from_slot > #slots or to_slot < 1 or to_slot > #slots then
            return slots, false, "Invalid slot index"
        end
        if slots[from_slot].gps == "1000000.1000000.1" then
            return slots, false, "No favorite in source slot"
        end
        
        -- Simple successful reorder for testing
        local new_slots = {}
        for i = 1, #slots do
            new_slots[i] = {gps = slots[i].gps, locked = slots[i].locked}
        end
        
        -- Simple swap for mock
        if new_slots[to_slot].gps == "1000000.1000000.1" then
            new_slots[to_slot] = {gps = new_slots[from_slot].gps, locked = new_slots[from_slot].locked}
            new_slots[from_slot] = {gps = "1000000.1000000.1", locked = false}
        end
        
        return new_slots, true, nil
    end,
    validate_drag_drop = function() return {can_drag_source = true, can_drop_target = true} end
}

-- Mock GuiObserver
_G.GuiObserver = {
    GuiEventBus = {
        notify = function() end
    },
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
            
            -- Check new reorder_favorites method - check if it exists as an instance method
            -- Create a temporary instance to check for instance methods
            local mock_player = {
                index = 1,
                name = "TestPlayer",
                valid = true,
                surface = { index = 1 }
            }
            local temp_instance = PlayerFavorites.new(mock_player)
            assert(type(temp_instance.reorder_favorites) == "function", "reorder_favorites should be a function")
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
            assert(type(instance.reorder_favorites) == "function", "instance should have reorder_favorites method")
        end)
        assert(success, "PlayerFavorites basic operations should work: " .. tostring(err))
    end)
    
    it("should handle reorder_favorites method", function()
        local success, err = pcall(function()
            local mock_player = {
                index = 1,
                name = "TestPlayer", 
                valid = true,
                surface = { index = 1 }
            }
            
            local PlayerFavorites = require("core.favorite.player_favorites")
            local instance = PlayerFavorites.new(mock_player)
            
            -- Test reorder_favorites method exists and returns expected values
            local success_result, error_msg = instance:reorder_favorites(1, 2)
            
            -- Should return boolean and optional string
            assert(type(success_result) == "boolean", "reorder_favorites should return boolean success")
            if not success_result then
                assert(type(error_msg) == "string", "reorder_favorites should return error message on failure")
            end
        end)
        assert(success, "PlayerFavorites reorder_favorites should work: " .. tostring(err))
    end)
end)
