--[[
test_chart_tag_ownership.lua
TeleportFavorites Factorio Mod
-----------------------------
Test chart tag ownership recording behavior to ensure temporary chart tags
don't record ownership while final confirmed chart tags do.
]]

local function test_chart_tag_ownership()
  print("🔧 Testing Chart Tag Ownership Recording...")
  
  -- Test that ChartTagUtils.build_chart_tag_spec properly controls ownership
  local ChartTagUtils = require("core.utils.chart_tag_utils")
  
  local mock_position = { x = 100, y = 100 }
  local mock_player = { name = "TestPlayer", valid = true }
  
  -- Test 1: Temporary chart tag should NOT record ownership
  local temp_spec = ChartTagUtils.build_chart_tag_spec(mock_position, nil, mock_player, "Temp Tag", false)
  
  if temp_spec.last_user then
    error("❌ FAIL: Temporary chart tag incorrectly recorded ownership")
  end
  print("✅ PASS: Temporary chart tag does not record ownership")
  
  -- Test 2: Final chart tag SHOULD record ownership
  local final_spec = ChartTagUtils.build_chart_tag_spec(mock_position, nil, mock_player, "Final Tag", true)
  
  if not final_spec.last_user or final_spec.last_user ~= "TestPlayer" then
    error("❌ FAIL: Final chart tag failed to record ownership")
  end
  print("✅ PASS: Final chart tag correctly records ownership")
  
  -- Test 3: GPSUtils functions should not record ownership for validation
  -- This requires mocking the validation functions since they check terrain
  local GPSUtils = require("core.utils.gps_utils")
  
  -- Mock the position validation to always return true
  local original_position_can_be_tagged = GPSUtils.position_can_be_tagged
  GPSUtils.position_can_be_tagged = function() return true end
  
  local validation_spec = GPSUtils.create_chart_tag_spec(mock_player, mock_position, "Validation Tag", nil, false)
  
  if validation_spec and validation_spec.last_user then
    error("❌ FAIL: Validation chart tag incorrectly recorded ownership")
  end
  print("✅ PASS: Validation chart tag does not record ownership")
  
  -- Test 4: GPSUtils with explicit ownership should record it
  local ownership_spec = GPSUtils.create_chart_tag_spec(mock_player, mock_position, "Ownership Tag", nil, true)
  
  if not ownership_spec or not ownership_spec.last_user or ownership_spec.last_user ~= "TestPlayer" then
    error("❌ FAIL: Explicit ownership chart tag failed to record ownership")
  end
  print("✅ PASS: Explicit ownership chart tag correctly records ownership")
  
  -- Restore original function
  GPSUtils.position_can_be_tagged = original_position_can_be_tagged
  
  print("🎉 Chart Tag Ownership tests completed successfully!")
  return true
end

-- Run if called directly
if not package.loaded["tests.test_chart_tag_ownership"] then
  local success, error_msg = pcall(test_chart_tag_ownership)
  if not success then
    print("❌ Chart Tag Ownership tests failed: " .. tostring(error_msg))
    return false
  end
end

return {
  test_chart_tag_ownership = test_chart_tag_ownership
}
