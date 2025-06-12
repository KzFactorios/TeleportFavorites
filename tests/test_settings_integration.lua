#!/usr/bin/env lua
--[[
test_settings_integration.lua
TeleportFavorites Settings Integration Test
------------------------------------------
This script validates that the settings are properly integrated and accessible.
Run this to verify settings functionality after the prototypes/settings.lua fixes.
]]

-- Mock Factorio environment for testing
local function setup_test_environment()
  -- Mock constants
  _G.Constants = {
    settings = {
      TELEPORT_RADIUS_DEFAULT = 8,
      TELEPORT_RADIUS_MIN = 1,
      TELEPORT_RADIUS_MAX = 32
    }
  }
  
  -- Mock player with settings
  local mock_player = {
    name = "TestPlayer",
    valid = true,
    mod_settings = {
      ["favorites-on"] = { value = true },
      ["teleport-radius"] = { value = 12 },
      ["destination-msg-on"] = { value = false }
    }
  }
  
  return mock_player
end

-- Load the settings module
package.path = package.path .. ";./?.lua"
local Settings = require("settings")

-- Test settings integration
local function test_settings_integration()
  local mock_player = setup_test_environment()
  
  print("=== TeleportFavorites Settings Integration Test ===")
  print()
  
  -- Test with valid player
  print("Testing with valid player and settings...")
  local player_settings = Settings:getPlayerSettings(mock_player)
  
  print("Retrieved settings:")
  print("  - teleport_radius:", player_settings.teleport_radius, "(expected: 12)")
  print("  - favorites_on:", player_settings.favorites_on, "(expected: true)")
  print("  - destination_msg_on:", player_settings.destination_msg_on, "(expected: false)")
  
  -- Validate results
  local success = true
  if player_settings.teleport_radius ~= 12 then
    print("❌ FAIL: teleport_radius should be 12, got", player_settings.teleport_radius)
    success = false
  end
  
  if player_settings.favorites_on ~= true then
    print("❌ FAIL: favorites_on should be true, got", player_settings.favorites_on)
    success = false
  end
  
  if player_settings.destination_msg_on ~= false then
    print("❌ FAIL: destination_msg_on should be false, got", player_settings.destination_msg_on)
    success = false
  end
  
  print()
  
  -- Test with nil player (should return defaults)
  print("Testing with nil player (should return defaults)...")
  local default_settings = Settings:getPlayerSettings(nil)
  
  print("Default settings:")
  print("  - teleport_radius:", default_settings.teleport_radius, "(expected: 8)")
  print("  - favorites_on:", default_settings.favorites_on, "(expected: true)")
  print("  - destination_msg_on:", default_settings.destination_msg_on, "(expected: true)")
  
  if default_settings.teleport_radius ~= 8 then
    print("❌ FAIL: default teleport_radius should be 8, got", default_settings.teleport_radius)
    success = false
  end
  
  if default_settings.favorites_on ~= true then
    print("❌ FAIL: default favorites_on should be true, got", default_settings.favorites_on)
    success = false
  end
  
  if default_settings.destination_msg_on ~= true then
    print("❌ FAIL: default destination_msg_on should be true, got", default_settings.destination_msg_on)
    success = false
  end
  
  print()
  
  if success then
    print("✅ ALL TESTS PASSED - Settings integration is working correctly!")
  else
    print("❌ SOME TESTS FAILED - Check settings implementation")
  end
  
  return success
end

-- Run the test
if arg and arg[0] and arg[0]:find("test_settings_integration") then
  test_settings_integration()
end

return { test_settings_integration = test_settings_integration }
