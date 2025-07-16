require("test_bootstrap")
require("mocks.factorio_test_env")

-- Mock dependencies
package.loaded["constants"] = {
    settings = {
        BLANK_GPS = "1000000.1000000.1"
    }
}

package.loaded["core.utils.error_handler"] = {
    debug_log = function() end
}

-- Use the complete mock enhanced error handler
package.loaded["core.utils.enhanced_error_handler"] = require("mocks.mock_enhanced_error_handler")

describe("DragDropUtils", function()
    it("should load module without errors", function()
        local success, err = pcall(function()
            local DragDropUtils = require("core.utils.drag_drop_utils")
            assert(DragDropUtils ~= nil, "DragDropUtils should load")
        end)
        assert(success, "DragDropUtils should load without errors: " .. tostring(err))
    end)
    
    it("should expose expected API methods", function()
        local DragDropUtils = require("core.utils.drag_drop_utils")
        assert(type(DragDropUtils.reorder_slots) == "function", "reorder_slots should exist")
        assert(type(DragDropUtils.validate_drag_drop) == "function", "validate_drag_drop should exist")
    end)
    
    it("should return three values from reorder_slots", function()
        local DragDropUtils = require("core.utils.drag_drop_utils")
        
        -- Create a simple slots array with BLANK_GPS
        local BLANK_GPS = "1000000.1000000.1"
        local slots = {
            {gps = "100.200.1", locked = false},
            {gps = BLANK_GPS, locked = false},
            {gps = "300.400.1", locked = false}
        }
        
        -- Test valid reorder operation
        local result_slots, success, error_msg = DragDropUtils.reorder_slots(slots, 1, 2)
        
        -- Should return all three values
        assert(type(result_slots) == "table", "Should return slots table")
        assert(type(success) == "boolean", "Should return success boolean")
        if not success then
            assert(type(error_msg) == "string", "Error message should be string when success is false")
        else
            assert(error_msg == nil, "Error message should be nil when success is true")
        end
    end)
    
    it("should handle invalid slot indices", function()
        local DragDropUtils = require("core.utils.drag_drop_utils")
        
        local BLANK_GPS = "1000000.1000000.1"
        local slots = {
            {gps = "100.200.1", locked = false},
            {gps = BLANK_GPS, locked = false}
        }
        
        -- Test invalid source index
        local result_slots, success, error_msg = DragDropUtils.reorder_slots(slots, 0, 1)
        assert(success == false, "Should fail for invalid source index")
        assert(type(error_msg) == "string", "Should return error message")
        
        -- Test invalid destination index
        local result_slots2, success2, error_msg2 = DragDropUtils.reorder_slots(slots, 1, 5)
        assert(success2 == false, "Should fail for invalid destination index")
        assert(type(error_msg2) == "string", "Should return error message")
    end)
    
    it("should handle blank source slot", function()
        local DragDropUtils = require("core.utils.drag_drop_utils")
        
        local BLANK_GPS = "1000000.1000000.1"
        local slots = {
            {gps = BLANK_GPS, locked = false},
            {gps = "300.400.1", locked = false}
        }
        
        -- Try to drag from blank slot
        local result_slots, success, error_msg = DragDropUtils.reorder_slots(slots, 1, 2)
        assert(success == false, "Should fail when dragging from blank slot")
        assert(error_msg == "No favorite in source slot", "Should return specific error message")
    end)
    
    it("should handle same source and destination", function()
        local DragDropUtils = require("core.utils.drag_drop_utils")
        
        local BLANK_GPS = "1000000.1000000.1"
        local slots = {
            {gps = "100.200.1", locked = false},
            {gps = BLANK_GPS, locked = false}
        }
        
        -- Try to drag to same slot
        local result_slots, success, error_msg = DragDropUtils.reorder_slots(slots, 1, 1)
        assert(success == false, "Should fail when source and destination are the same")
        assert(error_msg == "Source and destination slots are the same", "Should return specific error message")
    end)
    
    it("should successfully reorder to blank slot", function()
        local DragDropUtils = require("core.utils.drag_drop_utils")
        
        local BLANK_GPS = "1000000.1000000.1"
        local slots = {
            {gps = "100.200.1", locked = false},
            {gps = BLANK_GPS, locked = false}
        }
        
        -- Move item from slot 1 to blank slot 2
        local result_slots, success, error_msg = DragDropUtils.reorder_slots(slots, 1, 2)
        assert(success == true, "Should succeed when moving to blank slot")
        assert(error_msg == nil, "Should not return error message on success")
        assert(result_slots[2].gps == "100.200.1", "Item should be moved to destination")
        assert(result_slots[1].gps == BLANK_GPS, "Source should become blank")
    end)
    
    it("should handle locked source slot", function()
        local DragDropUtils = require("core.utils.drag_drop_utils")
        
        local BLANK_GPS = "1000000.1000000.1"
        local slots = {
            {gps = "100.200.1", locked = true},  -- Locked source
            {gps = BLANK_GPS, locked = false}
        }
        
        -- Try to drag from locked slot
        local result_slots, success, error_msg = DragDropUtils.reorder_slots(slots, 1, 2)
        assert(success == false, "Should fail when dragging from locked slot")
        assert(type(error_msg) == "string", "Should return error message")
    end)
    
    it("should handle locked destination slot", function()
        local DragDropUtils = require("core.utils.drag_drop_utils")
        
        local slots = {
            {gps = "100.200.1", locked = false},
            {gps = "300.400.1", locked = true}  -- Locked destination
        }
        
        -- Try to drag to locked slot
        local result_slots, success, error_msg = DragDropUtils.reorder_slots(slots, 1, 2)
        assert(success == false, "Should fail when dragging to locked slot")
        assert(type(error_msg) == "string", "Should return error message")
    end)
    
    it("should handle standard insert algorithm (slot 10 to slot 8 scenario)", function()
        local DragDropUtils = require("core.utils.drag_drop_utils")
        
        local BLANK_GPS = "1000000.1000000.1"
        -- Simulate the user's scenario: 10 slots with content, move slot 10 to slot 8
        local slots = {
            {gps = "100.200.1", locked = false},  -- slot 1
            {gps = "101.201.1", locked = false},  -- slot 2  
            {gps = "102.202.1", locked = false},  -- slot 3
            {gps = "103.203.1", locked = false},  -- slot 4
            {gps = "104.204.1", locked = false},  -- slot 5
            {gps = "105.205.1", locked = false},  -- slot 6
            {gps = "106.206.1", locked = false},  -- slot 7
            {gps = "107.207.1", locked = false},  -- slot 8
            {gps = "108.208.1", locked = false},  -- slot 9
            {gps = "109.209.1", locked = false}   -- slot 10
        }
        
        -- Move slot 10 to slot 8 
        local result_slots, success, error_msg = DragDropUtils.reorder_slots(slots, 10, 8)
        assert(success == true, "Move operation should succeed")
        assert(error_msg == nil, "Should not return error message on success")
        
        -- Expected behavior based on standard insert algorithm:
        -- - Item from slot 10 should be at position 8
        -- - What was in slot 8 should shift to position 9  
        -- - What was in slot 9 should shift to position 10
        -- - Slots 1-7 should remain unchanged
        assert(result_slots[8].gps == "109.209.1", "Slot 8 should contain original slot 10 content")
        assert(result_slots[9].gps == "107.207.1", "Slot 9 should contain original slot 8 content")  
        assert(result_slots[10].gps == "108.208.1", "Slot 10 should contain original slot 9 content")
        
        -- Verify first 7 slots unchanged
        for i = 1, 7 do
            assert(result_slots[i].gps == slots[i].gps, "Slot " .. i .. " should remain unchanged")
        end
    end)
    
    it("should handle insert algorithm with gap (slot 8 to slot 3 scenario)", function()
        local DragDropUtils = require("core.utils.drag_drop_utils")
        
        local BLANK_GPS = "1000000.1000000.1"
        -- Test moving from later position to earlier position
        local slots = {
            {gps = "100.200.1", locked = false},  -- slot 1
            {gps = "101.201.1", locked = false},  -- slot 2  
            {gps = "102.202.1", locked = false},  -- slot 3
            {gps = "103.203.1", locked = false},  -- slot 4
            {gps = "104.204.1", locked = false},  -- slot 5
            {gps = "105.205.1", locked = false},  -- slot 6
            {gps = "106.206.1", locked = false},  -- slot 7
            {gps = "107.207.1", locked = false}   -- slot 8
        }
        
        -- Move slot 8 to slot 3
        local result_slots, success, error_msg = DragDropUtils.reorder_slots(slots, 8, 3)
        assert(success == true, "Move operation should succeed")
        
        -- Expected: insert algorithm should place slot 8 content at position 3
        -- and shift everything else to the right
        assert(result_slots[3].gps == "107.207.1", "Slot 3 should contain original slot 8 content")
        assert(result_slots[4].gps == "102.202.1", "Slot 4 should contain original slot 3 content") 
        assert(result_slots[5].gps == "103.203.1", "Slot 5 should contain original slot 4 content")
        assert(result_slots[6].gps == "104.204.1", "Slot 6 should contain original slot 5 content")
        assert(result_slots[7].gps == "105.205.1", "Slot 7 should contain original slot 6 content")
        assert(result_slots[8].gps == "106.206.1", "Slot 8 should contain original slot 7 content")
        
        -- Verify first 2 slots unchanged
        assert(result_slots[1].gps == "100.200.1", "Slot 1 should remain unchanged")
        assert(result_slots[2].gps == "101.201.1", "Slot 2 should remain unchanged")
    end)
end)
