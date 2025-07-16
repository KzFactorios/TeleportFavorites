require("test_bootstrap")
require("mocks.factorio_test_env")

describe("TeleportHistoryModal", function()
    it("should load module without errors", function()
        local success, err = pcall(function()
            local TeleportHistoryModal = require("gui.teleport_history_modal.teleport_history_modal")
            assert(TeleportHistoryModal ~= nil, "TeleportHistoryModal should load")
        end)
        assert(success, "TeleportHistoryModal should load without errors: " .. tostring(err))
    end)
    
    it("should expose expected API methods", function()
        local TeleportHistoryModal = require("gui.teleport_history_modal.teleport_history_modal")
        assert(type(TeleportHistoryModal.build) == "function", "build method should exist")
        assert(type(TeleportHistoryModal.destroy) == "function", "destroy method should exist")
        assert(type(TeleportHistoryModal.update_history_list) == "function", "update_history_list method should exist")
        assert(type(TeleportHistoryModal.is_open) == "function", "is_open method should exist")
    end)
    
    it("should handle basic function calls without crashing", function()
        local TeleportHistoryModal = require("gui.teleport_history_modal.teleport_history_modal")
        local PlayerFavoritesMocks = require("mocks.player_favorites_mocks")
        
        -- Mock a basic player
        local player = PlayerFavoritesMocks.mock_player(1, "TestPlayer", 1)
        
        -- Test that functions can be called without crashing
        local success, err = pcall(function()
            TeleportHistoryModal.is_open(player)
            TeleportHistoryModal.destroy(player)
        end)
        
        assert(success, "Basic TeleportHistoryModal functions should not crash: " .. tostring(err))
    end)
end)
