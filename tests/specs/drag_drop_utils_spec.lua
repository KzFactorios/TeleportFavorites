---@diagnostic disable: undefined-global
require("test_framework")

describe("DragDropUtils", function()
    local DragDropUtils
    local BLANK_GPS = "1000000.1000000.1"
    
    before_each(function()
        -- Mock all dependencies
        package.loaded["constants"] = {
            settings = {
                BLANK_GPS = BLANK_GPS
            }
        }

        package.loaded["core.utils.error_handler"] = {
            debug_log = function() end
        }

        -- Mock enhanced error handler with debug_log function
        package.loaded["core.utils.enhanced_error_handler"] = {
            debug_log = function(msg, data) 
                -- Silent mock - no output during tests
            end,
            info = function() end,
            warn = function() end,
            error = function() end,
            trace = function() end,
            debug = function() end
        }

        -- Mock BasicHelpers
        package.loaded["core.utils.basic_helpers"] = {
            deep_copy = function(obj)
                if type(obj) ~= "table" then return obj end
                local copy = {}
                for k, v in pairs(obj) do
                    if type(v) == "table" then
                        copy[k] = package.loaded["core.utils.basic_helpers"].deep_copy(v)
                    else
                        copy[k] = v
                    end
                end
                return copy
            end,
            is_blank_favorite = function(favorite)
                return favorite and favorite.gps == BLANK_GPS
            end,
            is_locked_favorite = function(favorite)
                return favorite and favorite.locked == true
            end
        }

        -- Mock Enum
        package.loaded["prototypes.enums.enum"] = {}
        
        -- Load the module under test
        local success, result = pcall(require, "core.utils.drag_drop_utils")
        if success then
            DragDropUtils = result
        else
            error("Failed to load DragDropUtils module: " .. tostring(result))
        end
    end)
    it("should load module without errors", function()
        assert(DragDropUtils ~= nil, "DragDropUtils should load")
        assert(type(DragDropUtils.reorder_slots) == "function", "reorder_slots should exist")
        assert(type(DragDropUtils.validate_drag_drop) == "function", "validate_drag_drop should exist")
    end)
    
    it("should return three values from reorder_slots", function()
        -- Create a simple slots array with BLANK_GPS
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
            assert(error_msg == "", "Error message should be empty string when success is true")
        end
    end)
    
    it("should handle invalid slot indices", function()
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
        local slots = {
            {gps = BLANK_GPS, locked = false},
            {gps = "300.400.1", locked = false}
        }
        
        -- Try to drag from blank slot
        local result_slots, success, error_msg = DragDropUtils.reorder_slots(slots, 1, 2)
        assert(success == false, "Should fail when dragging from blank slot")
        assert(error_msg == "source_is_blank", "Should return specific error message")
    end)
    
    it("should handle same source and destination", function()
        local slots = {
            {gps = "100.200.1", locked = false},
            {gps = BLANK_GPS, locked = false}
        }
        
        -- Try to drag to same slot
        local result_slots, success, error_msg = DragDropUtils.reorder_slots(slots, 1, 1)
        assert(success == false, "Should fail when source and destination are the same")
        assert(error_msg == "same_slot", "Should return specific error message")
    end)
    
    it("should successfully reorder to blank slot", function()
        local slots = {
            {gps = "100.200.1", locked = false},
            {gps = BLANK_GPS, locked = false}
        }
        
        -- Move item from slot 1 to blank slot 2
        local result_slots, success, error_msg = DragDropUtils.reorder_slots(slots, 1, 2)
        assert(success == true, "Should succeed when moving to blank slot")
        assert(error_msg == "", "Should return empty string on success")
        assert(result_slots[2].gps == "100.200.1", "Item should be moved to destination")
        assert(result_slots[1].gps == BLANK_GPS, "Source should become blank")
    end)
    
    it("should handle locked source slot", function()
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
        local slots = {
            {gps = "100.200.1", locked = false},
            {gps = "300.400.1", locked = true}  -- Locked destination
        }
        
        -- Try to drag to locked slot
        local result_slots, success, error_msg = DragDropUtils.reorder_slots(slots, 1, 2)
        assert(success == false, "Should fail when dragging to locked slot")
        assert(type(error_msg) == "string", "Should return error message")
    end)
    
    it("should handle blank-seeking cascade algorithm (slot 10 to slot 8 scenario)", function()
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
        assert(error_msg == "", "Should return empty string on success")
        
        -- Expected behavior based on blank-seeking cascade algorithm:
        -- 1. Slot 10 becomes blank (source evacuation)
        -- 2. Find blank between slots 9-8: blank found at slot 10 position
        -- 3. Cascade items leftward toward blank: slot 9 → slot 10
        -- 4. Place slot 10 content at slot 8: original slot 10 → slot 8
        -- 5. What was in slot 8 gets displaced to slot 9
        assert(result_slots[8].gps == "109.209.1", "Slot 8 should contain original slot 10 content")
        assert(result_slots[9].gps == "107.207.1", "Slot 9 should contain original slot 8 content")
        assert(result_slots[10].gps == "108.208.1", "Slot 10 should contain original slot 9 content")
        
        -- Verify first 7 slots unchanged
        for i = 1, 7 do
            assert(result_slots[i].gps == slots[i].gps, "Slot " .. i .. " should remain unchanged")
        end
    end)
    
    it("should handle blank-seeking cascade with intermediate blank", function()
        -- Test with an intermediate blank slot
        local slots = {
            {gps = "100.200.1", locked = false},  -- slot 1
            {gps = "101.201.1", locked = false},  -- slot 2  
            {gps = "102.202.1", locked = false},  -- slot 3
            {gps = BLANK_GPS, locked = false},    -- slot 4 (blank)
            {gps = "104.204.1", locked = false},  -- slot 5
            {gps = "105.205.1", locked = false},  -- slot 6
            {gps = "106.206.1", locked = false},  -- slot 7
            {gps = "107.207.1", locked = false}   -- slot 8
        }
        
        -- Move slot 8 to slot 3 (leftward move with intermediate blank)
        local result_slots, success, error_msg = DragDropUtils.reorder_slots(slots, 8, 3)
        assert(success == true, "Move operation should succeed")
        
        -- Expected behavior:
        -- 1. Slot 8 becomes blank (source evacuation)  
        -- 2. Find blank between slots 4-7: blank found at slot 4
        -- 3. Cascade items rightward toward blank at slot 4
        -- 4. Place slot 8 content at slot 3
        assert(result_slots[3].gps == "107.207.1", "Slot 3 should contain original slot 8 content")
        
        -- Verify first 2 slots unchanged
        assert(result_slots[1].gps == "100.200.1", "Slot 1 should remain unchanged")
        assert(result_slots[2].gps == "101.201.1", "Slot 2 should remain unchanged")
    end)
    
    it("should handle adjacent slot moves (simple swap)", function()
        local slots = {
            {gps = "100.200.1", locked = false},  -- slot 1
            {gps = "101.201.1", locked = false},  -- slot 2  
            {gps = "102.202.1", locked = false}   -- slot 3
        }
        
        -- Move adjacent slots: slot 1 to slot 2
        local result_slots, success, error_msg = DragDropUtils.reorder_slots(slots, 1, 2)
        assert(success == true, "Adjacent move should succeed")
        
        -- Expected: simple swap for adjacent slots
        assert(result_slots[1].gps == "101.201.1", "Slot 1 should contain original slot 2 content")
        assert(result_slots[2].gps == "100.200.1", "Slot 2 should contain original slot 1 content")
        assert(result_slots[3].gps == "102.202.1", "Slot 3 should remain unchanged")
    end)
    
    it("should respect locked slots during cascade operations", function()
        local slots = {
            {gps = "100.200.1", locked = false},  -- slot 1
            {gps = "101.201.1", locked = false},  -- slot 2  
            {gps = "102.202.1", locked = true},   -- slot 3 (locked)
            {gps = "103.203.1", locked = false},  -- slot 4
            {gps = "104.204.1", locked = false}   -- slot 5
        }
        
        -- Try to move across locked slot: slot 5 to slot 2
        local result_slots, success, error_msg = DragDropUtils.reorder_slots(slots, 5, 2)
        assert(success == true, "Move operation should succeed even with locked slots in path")
        
        -- Algorithm should skip locked slots during cascade
        assert(result_slots[2].gps == "104.204.1", "Slot 2 should contain original slot 5 content")
        assert(result_slots[3].gps == "102.202.1", "Slot 3 (locked) should remain unchanged")
    end)
end)
