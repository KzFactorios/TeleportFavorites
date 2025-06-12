-- tests/test_tag_editor_data_factory.lua
-- Test file for the centralized tag_editor_data factory method

local Cache = require("core.cache.cache")

local function test_create_tag_editor_data_defaults()
  print("Testing create_tag_editor_data with defaults...")
  
  local result = Cache.create_tag_editor_data()
  
  -- Test all expected fields are present with correct default values
  assert(result.gps == "", "gps should default to empty string")
  assert(result.move_gps == "", "move_gps should default to empty string")
  assert(result.locked == false, "locked should default to false")
  assert(result.is_favorite == false, "is_favorite should default to false")
  assert(result.icon == "", "icon should default to empty string")
  assert(result.text == "", "text should default to empty string")
  assert(result.tag == nil, "tag should default to nil")
  assert(result.chart_tag == nil, "chart_tag should default to nil")
  assert(result.error_message == "", "error_message should default to empty string")
  
  print("✓ Default values test passed")
end

local function test_create_tag_editor_data_with_options()
  print("Testing create_tag_editor_data with options...")
  
  local options = {
    gps = "100.200.1",
    locked = true,
    is_favorite = true,
    icon = "signal-A",
    text = "Test Tag"
  }
  
  local result = Cache.create_tag_editor_data(options)
  
  -- Test provided options are used
  assert(result.gps == "100.200.1", "gps should use provided value")
  assert(result.locked == true, "locked should use provided value")
  assert(result.is_favorite == true, "is_favorite should use provided value")
  assert(result.icon == "signal-A", "icon should use provided value")
  assert(result.text == "Test Tag", "text should use provided value")
  
  -- Test unprovided options use defaults
  assert(result.move_gps == "", "move_gps should use default value")
  assert(result.tag == nil, "tag should use default value")
  assert(result.chart_tag == nil, "chart_tag should use default value")
  assert(result.error_message == "", "error_message should default to empty string")
  
  print("✓ Options override test passed")
end

local function test_create_tag_editor_data_with_nil_options()
  print("Testing create_tag_editor_data with nil options...")
  
  local result = Cache.create_tag_editor_data(nil)
  
  -- Should behave same as no options
  assert(result.gps == "", "gps should default to empty string")
  assert(result.move_gps == "", "move_gps should default to empty string")
  assert(result.locked == false, "locked should default to false")
  
  print("✓ Nil options test passed")
end

local function test_create_tag_editor_data_with_partial_options()
  print("Testing create_tag_editor_data with partial options...")
  
  local options = {
    gps = "50.75.2",
    text = "Partial Test"
    -- Only some fields provided
  }
  
  local result = Cache.create_tag_editor_data(options)
  
  -- Test provided options are used
  assert(result.gps == "50.75.2", "gps should use provided value")
  assert(result.text == "Partial Test", "text should use provided value")
  
  -- Test unprovided options use defaults
  assert(result.move_gps == "", "move_gps should use default value")
  assert(result.locked == false, "locked should use default value")
  assert(result.is_favorite == false, "is_favorite should use default value")
  assert(result.icon == "", "icon should use default value")
  
  print("✓ Partial options test passed")
end

local function run_all_tests()
  print("Running tag_editor_data factory tests...")
  print("=" .. string.rep("=", 50))
  
  test_create_tag_editor_data_defaults()
  test_create_tag_editor_data_with_options()
  test_create_tag_editor_data_with_nil_options()
  test_create_tag_editor_data_with_partial_options()
  
  print("=" .. string.rep("=", 50))
  print("✅ All tests passed successfully!")
  print("The centralized tag_editor_data factory is working correctly.")
end

-- Export for potential external use
return {
  run_all_tests = run_all_tests,
  test_create_tag_editor_data_defaults = test_create_tag_editor_data_defaults,
  test_create_tag_editor_data_with_options = test_create_tag_editor_data_with_options,
  test_create_tag_editor_data_with_nil_options = test_create_tag_editor_data_with_nil_options,
  test_create_tag_editor_data_with_partial_options = test_create_tag_editor_data_with_partial_options
}
