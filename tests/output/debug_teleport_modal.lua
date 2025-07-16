-- Debug script to test teleport history modal creation
require("test_bootstrap")
require("mocks.factorio_test_env")

-- Test just the modal creation
local function test_modal_creation()
    print("Testing teleport history modal creation...")
    
    local success, err = pcall(function()
        local TeleportHistoryModal = require("gui.teleport_history_modal.teleport_history_modal")
        assert(TeleportHistoryModal ~= nil, "Modal module should load")
        assert(type(TeleportHistoryModal.build) == "function", "build function should exist")
        print("✓ Modal module loaded successfully")
    end)
    
    if not success then
        print("✗ Error loading modal: " .. tostring(err))
        return false
    end
    
    print("✓ All modal tests passed!")
    return true
end

-- Run the test
test_modal_creation()
