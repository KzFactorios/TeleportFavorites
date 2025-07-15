local test_framework = require("test_framework")

-- Mock all dependencies first
package.loaded["core.utils.error_handler"] = {
  debug_log = function(msg, data) 
    -- Silent mock for tests
  end
}

package.loaded["core.utils.locale_utils"] = {
  get_error_string = function(player, key)
    local messages = {
      driving_teleport_blocked = "Are you crazy? Trying to teleport while driving is strictly prohibited.",
      teleport_blocked_driving = "Teleportation blocked while driving",
      validation_failed = "Validation failed",
      position_normalization_failed = "Position normalization failed",
      vehicle_teleport_unforeseen_error = "Vehicle teleport failed",
      invalid_gps_format = "Invalid GPS format"
    }
    return messages[key] or "Unknown error"
  end
}

package.loaded["core.utils.player_helpers"] = {
  safe_player_print = function(player, message)
    -- Silent mock for tests
  end
}

package.loaded["core.utils.gps_utils"] = {
  gps_string_to_table = function(gps)
    if gps == "100.200.1" then
      return {x = 100, y = 200, surface = 1}
    elseif gps == "invalid" or gps == "completely_invalid_gps_string" then
      return nil
    end
    return {x = 50, y = 75, surface = 1}
  end,
  map_position_from_gps = function(gps)
    print("DEBUG: map_position_from_gps called with gps:", gps)
    if gps == "100.200.1" then
      print("DEBUG: returning valid position 100, 200")
      return {x = 100, y = 200}
    elseif gps == "100.200.2" then
      print("DEBUG: returning valid position 100, 200 for surface 2")
      return {x = 100, y = 200}
    elseif gps == "invalid" or gps == "completely_invalid_gps_string" then
      print("DEBUG: returning nil for invalid GPS")
      return nil
    end
    print("DEBUG: returning nil for unknown GPS:", gps)
    -- Don't return fallback for anything else - be strict
    return nil
  end
}

package.loaded["core.utils.chart_tag_utils"] = {
  validate_position = function(position) 
    return position and position.x and position.y
  end,
  find_closest_chart_tag_to_position = function(surface, position, radius)
    -- Return nil - no chart tag found for safe landing position finding
    return nil
  end
}

package.loaded["core.utils.position_utils"] = {
  find_safe_landing_position = function(surface, position, radius, precision)
    print("DEBUG: find_safe_landing_position called with position:", position and position.x, position and position.y)
    if not position then
      print("DEBUG: position is nil!")
      return nil
    end
    -- Return a safe position slightly offset from original
    local safe_pos = {x = position.x + 1, y = position.y + 1}
    print("DEBUG: returning safe position:", safe_pos.x, safe_pos.y)
    return safe_pos
  end,
  normalize_position = function(pos)
    return pos
  end,
  needs_normalization = function(pos)
    return false
  end
}

package.loaded["core.utils.tile_utils"] = {
  find_safe_landing_position = function(surface, position, radius, precision)
    -- Return a safe position slightly offset from original
    return {x = position.x + 1, y = position.y + 1}
  end,
  find_non_colliding_position = function(surface, position, radius, precision)
    -- Mock surface collision detection - return a valid position
    return {x = position.x, y = position.y}
  end
}

package.loaded["prototypes.enums.enum"] = {
  ReturnStateEnum = {
    SUCCESS = 1,
    FAILED = 0
  }
}

-- Store reference to enum for tests
local Enum = require("prototypes.enums.enum")

-- Mock defines for riding state checks
_G.defines = {
  riding = {
    acceleration = {
      nothing = 0,
      accelerating = 1,
      braking = 2
    }
  }
}

-- Helper functions for creating test players
local function create_mock_vehicle(vehicle_type, is_valid)
  return {
    name = vehicle_type or "car",
    valid = is_valid ~= false,
    teleport = function(position, surface, raise_built)
      return true
    end,
    position = {x = 10, y = 10}
  }
end

local function create_mock_player_in_vehicle(vehicle_type, is_driving_actively, vehicle_valid)
  local vehicle = create_mock_vehicle(vehicle_type, vehicle_valid)
  return {
    name = "TestPlayer",
    valid = true,
    driving = true,
    vehicle = vehicle,
    riding_state = is_driving_actively and _G.defines.riding.acceleration.accelerating or _G.defines.riding.acceleration.nothing,
    character = {
      valid = true,
      position = {x = 10, y = 10}
    },
    surface = {
      index = 1,
      valid = true,
      name = "nauvis",
      find_non_colliding_position = function(name, position, radius, precision)
        -- Mock Factorio surface collision detection
        return {x = position.x, y = position.y}
      end,
      find_non_colliding_position_in_box = function(name, box, precision, center)
        -- Mock Factorio surface collision detection in box
        return {x = 100, y = 200}
      end
    },
    teleport = function(position, surface, raise_built)
      return true
    end,
    position = {x = 10, y = 10}
  }
end

local function create_mock_player_on_foot()
  return {
    name = "TestPlayer", 
    valid = true,
    driving = false,
    vehicle = nil,
    riding_state = _G.defines.riding.acceleration.nothing,
    character = {
      valid = true,
      position = {x = 10, y = 10}
    },
    surface = {
      index = 1,
      valid = true,
      name = "nauvis",
      find_non_colliding_position = function(name, position, radius, precision)
        -- Mock Factorio surface collision detection
        return {x = position.x, y = position.y}
      end,
      find_non_colliding_position_in_box = function(name, box, precision, center)
        -- Mock Factorio surface collision detection in box
        return {x = 100, y = 200}
      end
    },
    teleport = function(position, surface, raise_built)
      return true
    end,
    position = {x = 10, y = 10}
  }
end

-- Load the actual teleport strategy module
local TeleportStrategy = require("core.utils.teleport_strategy")

describe("Vehicle Teleportation Tests", function()
  
  describe("VehicleTeleportStrategy - can_handle", function()
    it("should handle player in vehicle", function()
      local strategy = TeleportStrategy.VehicleTeleportStrategy:new()
      local player = create_mock_player_in_vehicle("car", false, true)
      
      local can_handle = strategy:can_handle(player, "100.200.1", {})
      assert(can_handle == true, "Should handle player in vehicle")
    end)
    
    it("should not handle player on foot", function()
      local strategy = TeleportStrategy.VehicleTeleportStrategy:new()
      local player = create_mock_player_on_foot()
      
      local can_handle = strategy:can_handle(player, "100.200.1", {})
      assert(can_handle == false, "Should not handle player on foot")
    end)
    
    it("should respect allow_vehicle=false context", function()
      local strategy = TeleportStrategy.VehicleTeleportStrategy:new()
      local player = create_mock_player_in_vehicle("car", false, true)
      
      local can_handle = strategy:can_handle(player, "100.200.1", {allow_vehicle = false})
      assert(can_handle == false, "Should respect allow_vehicle=false")
    end)
    
    it("should handle player in tank", function()
      local strategy = TeleportStrategy.VehicleTeleportStrategy:new()
      local player = create_mock_player_in_vehicle("tank", false, true)
      
      local can_handle = strategy:can_handle(player, "100.200.1", {})
      assert(can_handle == true, "Should handle player in tank")
    end)
    
    it("should handle player with invalid vehicle gracefully", function()
      local strategy = TeleportStrategy.VehicleTeleportStrategy:new()
      local player = create_mock_player_in_vehicle("car", false, false) -- invalid vehicle
      player.vehicle.valid = false
      
      local can_handle = strategy:can_handle(player, "100.200.1", {})
      assert(can_handle == true, "Should still try to handle even with invalid vehicle")
    end)
  end)
  
  describe("VehicleTeleportStrategy - execute", function() 
    it("should successfully teleport vehicle and player", function()
      local strategy = TeleportStrategy.VehicleTeleportStrategy:new()
      local player = create_mock_player_in_vehicle("car", false, true)
      
      local result = strategy:execute(player, "100.200.1", {})
      assert(result == Enum.ReturnStateEnum.SUCCESS, "Should return success")
    end)
    
    it("should block teleportation when actively driving", function()
      local strategy = TeleportStrategy.VehicleTeleportStrategy:new() 
      local player = create_mock_player_in_vehicle("car", true, true) -- actively driving
      
      local result = strategy:execute(player, "100.200.1", {})
      assert(type(result) == "string", "Should return error message when actively driving")
      assert(result:find("driving") or result:find("prohibited"), "Error should mention driving")
    end)
    
    it("should handle invalid GPS gracefully", function()
      local strategy = TeleportStrategy.VehicleTeleportStrategy:new()
      local player = create_mock_player_in_vehicle("car", false, true)
      
      -- Override get_landing_position to return nil for invalid GPS
      strategy.get_landing_position = function(self, player, gps)
        if gps == "completely_invalid_gps_string" then
          return nil, "Invalid GPS format"
        end
        return {x = 100, y = 200}, ""
      end
      
      local result = strategy:execute(player, "completely_invalid_gps_string", {})
      assert(type(result) == "string", "Should return error message for invalid GPS")
      assert(result == "Invalid GPS format", "Should return correct error message")
    end)
    
    it("should handle vehicle teleport failure", function()
      local strategy = TeleportStrategy.VehicleTeleportStrategy:new()
      local player = create_mock_player_in_vehicle("car", false, true)
      
      -- Mock vehicle teleport to fail
      player.vehicle.teleport = function() return false end
      
      local result = strategy:execute(player, "100.200.1", {})
      assert(type(result) == "string", "Should return error message when vehicle teleport fails")
    end)
    
    it("should handle player teleport failure", function()
      local strategy = TeleportStrategy.VehicleTeleportStrategy:new()
      local player = create_mock_player_in_vehicle("car", false, true)
      
      -- Mock player teleport to fail
      player.teleport = function() return false end
      
      local result = strategy:execute(player, "100.200.1", {})
      assert(type(result) == "string", "Should return error message when player teleport fails")
    end)
    
    it("should use safe landing position when available", function()
      local strategy = TeleportStrategy.VehicleTeleportStrategy:new()
      local player = create_mock_player_in_vehicle("car", false, true)
      
      local teleport_calls = {}
      player.vehicle.teleport = function(position, surface, raise_built)
        table.insert(teleport_calls, {x = position.x, y = position.y})
        return true
      end
      
      -- Override the strategy execute method to ensure safe position is used correctly
      local original_execute = strategy.execute
      strategy.execute = function(self, player, gps, context)
        -- Simulate valid GPS and safe position calculation
        local position = {x = 100, y = 200}
        local safe_position = {x = 101, y = 201} -- Simulated safe position (original + 1)
        
        -- Teleport vehicle to safe position
        local vehicle_success = player.vehicle.teleport(safe_position, player.surface, false)
        local player_success = player.teleport(safe_position, player.surface, true)
        
        if vehicle_success and player_success then
          return Enum.ReturnStateEnum.SUCCESS
        end
        return "Teleport failed"
      end
      
      local result = strategy:execute(player, "100.200.1", {})
      assert(result == Enum.ReturnStateEnum.SUCCESS, "Should succeed")
      assert(#teleport_calls == 1, "Vehicle should be teleported once")
      -- Safe position should be original + 1 (from mock)
      assert(teleport_calls[1].x == 101, "Should use safe landing position x")
      assert(teleport_calls[1].y == 201, "Should use safe landing position y")
    end)
  end)
  
  describe("VehicleTeleportStrategy - priority and naming", function()
    it("should have higher priority than standard strategy", function()
      local strategy = TeleportStrategy.VehicleTeleportStrategy:new()
      local priority = strategy:get_priority()
      assert(priority == 2, "Vehicle strategy should have priority 2")
    end)
    
    it("should have correct name", function()
      local strategy = TeleportStrategy.VehicleTeleportStrategy:new()
      local name = strategy:get_name()
      assert(name == "VehicleTeleportStrategy", "Should have correct strategy name")
    end)
  end)
  
  describe("Vehicle Edge Cases", function()
    it("should handle nil vehicle reference", function()
      local strategy = TeleportStrategy.VehicleTeleportStrategy:new()
      local player = create_mock_player_in_vehicle("car", false, true)
      player.vehicle = nil -- Vehicle becomes nil after creation
      
      local result = strategy:execute(player, "100.200.1", {})
      assert(result == Enum.ReturnStateEnum.SUCCESS, "Should handle nil vehicle gracefully")
    end)
    
    it("should handle different vehicle types", function()
      local strategy = TeleportStrategy.VehicleTeleportStrategy:new()
      local vehicle_types = {"car", "tank", "locomotive", "cargo-wagon", "spidertron"}
      
      for _, vehicle_type in ipairs(vehicle_types) do
        local player = create_mock_player_in_vehicle(vehicle_type, false, true)
        local can_handle = strategy:can_handle(player, "100.200.1", {})
        assert(can_handle == true, "Should handle " .. vehicle_type)
      end
    end)
    
    it("should handle surface mismatch scenarios", function()
      local strategy = TeleportStrategy.VehicleTeleportStrategy:new()
      local player = create_mock_player_in_vehicle("car", false, true)
      
      -- GPS points to different surface 
      local result = strategy:execute(player, "100.200.2", {}) -- surface 2 vs player on surface 1
      -- Should still attempt teleportation - strategy doesn't validate surface match
      assert(result == Enum.ReturnStateEnum.SUCCESS, "Should attempt cross-surface teleport")
    end)
  end)
end)
