-- Debug script to test vehicle teleport failure
package.path = package.path .. ';./?.lua'

-- Mock all dependencies
package.loaded["core.utils.error_handler"] = {
  debug_log = function(msg, data) 
    print("[MOCK ERROR HANDLER] debug_log called: " .. tostring(msg))
  end
}

package.loaded["core.utils.locale_utils"] = {
  get_error_string = function(player, key)
    local messages = {
      vehicle_teleport_unforeseen_error = "Vehicle teleport failed"
    }
    print("LocaleUtils.get_error_string called with key: " .. tostring(key))
    local result = messages[key] or "Unknown error"
    print("Returning: " .. tostring(result))
    return result
  end
}

package.loaded["core.utils.player_helpers"] = {
  safe_player_print = function(player, message)
    print("[MOCK PLAYER HELPERS] safe_player_print called: " .. tostring(message))
  end
}

package.loaded["core.utils.gps_utils"] = {
  map_position_from_gps = function(gps)
    print("GPS Utils: parsing " .. tostring(gps))
    return {x = 100, y = 200}
  end
}

package.loaded["core.utils.position_utils"] = {
  find_safe_landing_position = function(surface, position, radius, precision)
    print("DEBUG: find_safe_landing_position called with position: " .. position.x .. "\t" .. position.y)
    local safe_pos = {x = position.x + 1, y = position.y + 1}
    print("DEBUG: returning safe position: " .. safe_pos.x .. "\t" .. safe_pos.y)
    return safe_pos
  end
}

package.loaded["core.utils.chart_tag_utils"] = {
  find_closest_chart_tag_to_position = function(surface, position, radius)
    return nil -- No chart tag found
  end
}
package.loaded["prototypes.enums.enum"] = {
  ReturnStateEnum = {
    SUCCESS = 1
  }
}

-- Load the teleport strategy
local TeleportStrategy = require("core.utils.teleport_strategy")

-- Create mock player in vehicle
local vehicle = {
  valid = true,
  name = "car",
  teleport = function() 
    print("Vehicle teleport called - returning false")
    return false 
  end
}

local player = {
  name = "TestPlayer",
  valid = true,
  vehicle = vehicle,
  character = { valid = true },
  surface = {
    valid = true,
    index = 1
  },
  teleport = function(position, surface, raise_built)
    print("Player teleport called - returning true")
    return true
  end
}

-- Test the strategy
local strategy = TeleportStrategy.VehicleTeleportStrategy:new()
print("Testing vehicle teleport failure...")
local result = strategy:execute(player, "100.200.1", {})
print("Result type: " .. type(result))
print("Result value: " .. tostring(result))
print("Test assertion would be: " .. tostring(type(result) == "string"))
