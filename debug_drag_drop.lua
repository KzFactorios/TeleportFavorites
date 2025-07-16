-- Debug script for drag_drop_utils
local BLANK_GPS = "1000000.1000000.1"

-- Mock the dependencies exactly like in the test
package.loaded["constants"] = {
    settings = {
        BLANK_GPS = BLANK_GPS
    }
}

package.loaded["core.utils.error_handler"] = {
    debug_log = function() end
}

package.loaded["core.utils.enhanced_error_handler"] = {
    debug_log = function() end
}

package.loaded["core.utils.basic_helpers"] = {
    deep_copy = function(obj)
        if type(obj) ~= "table" then return obj end
        local copy = {}
        for k, v in pairs(obj) do
            copy[k] = package.loaded["core.utils.basic_helpers"].deep_copy(v)
        end
        return copy
    end,
    is_blank_favorite = function(favorite)
        print("is_blank_favorite called with:", favorite and favorite.gps or "nil")
        return favorite and favorite.gps == BLANK_GPS
    end,
    is_locked_favorite = function(favorite)
        return favorite and favorite.locked == true
    end
}

package.loaded["prototypes.enums.enum"] = {}

-- Now test the actual module
local DragDropUtils = require("core.utils.drag_drop_utils")

print("Testing blank source slot scenario...")
local slots = {
    {gps = BLANK_GPS, locked = false},
    {gps = "300.400.1", locked = false}
}

print("Slot 1 GPS:", slots[1].gps)
print("Slot 2 GPS:", slots[2].gps)
print("BLANK_GPS constant:", BLANK_GPS)

local result_slots, success, error_msg = DragDropUtils.reorder_slots(slots, 1, 2)

print("Result - Success:", success)
print("Result - Error:", error_msg)
print("Expected: success=false, error='source_is_blank'")

if success == false and error_msg == "source_is_blank" then
    print("✅ TEST PASSED")
else
    print("❌ TEST FAILED")
end
