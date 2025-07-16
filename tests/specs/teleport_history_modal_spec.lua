-- Simple test to verify teleport history modal functionality
local TeleportHistoryModal = require("gui.teleport_history_modal.teleport_history_modal")
local TeleportHistory = require("core.teleport.teleport_history")

-- Mock player for testing
local function create_mock_player()
  return {
    index = 1,
    name = "test_player",
    surface = {
      index = 1,
      name = "nauvis"
    },
    gui = {
      screen = {}
    },
    valid = true,
    opened = nil
  }
end

local function test_teleport_history_modal()
  print("Testing teleport history modal...")
  
  local player = create_mock_player()
  
  -- Test 1: Modal should not be open initially
  assert(not TeleportHistoryModal.is_open(player), "Modal should not be open initially")
  print("✓ Modal not open initially")
  
  -- Test 2: Modal module should have expected functions
  assert(type(TeleportHistoryModal.build) == "function", "Should have build function")
  assert(type(TeleportHistoryModal.destroy) == "function", "Should have destroy function")  
  assert(type(TeleportHistoryModal.update_history_list) == "function", "Should have update_history_list function")
  assert(type(TeleportHistoryModal.is_open) == "function", "Should have is_open function")
  print("✓ All expected functions exist")
  
  -- Test 3: TeleportHistory should have expected functions for GPS conversion
  assert(type(TeleportHistory.get_gps_string) == "function", "Should have get_gps_string function")
  assert(type(TeleportHistory.teleport_to_pointer) == "function", "Should have teleport_to_pointer function")
  print("✓ TeleportHistory functions available")
  
  print("All teleport history modal tests passed!")
end

test_teleport_history_modal()
