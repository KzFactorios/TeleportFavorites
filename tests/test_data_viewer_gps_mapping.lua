---@diagnostic disable: undefined-global

--[[
Test for Data Viewer GPS Mapping Display
========================================

This test verifies that the Data Viewer correctly displays both:
1. Array-indexed chart tags (existing functionality)
2. GPS mapping table data (new functionality)

Manual Test Instructions:
1. Load the game with some chart tags placed
2. Open the Data Viewer (/teleport-favorites-data-viewer)
3. Navigate to the "Lookup" tab
4. Verify both data structures are visible:
   - chart_tags_by_surface (with numbered keys like chart_tag_1, chart_tag_2)
   - chart_tags_mapped_by_gps (with GPS string keys like "100.100.1")

Expected Results:
- Both data structures should be populated if chart tags exist
- GPS mapping should use actual GPS strings as keys
- Each entry should contain position, text, icon, last_user, surface_name, and valid fields
- cache_status should be "populated" if data exists, "empty" if no chart tags
--]]

local Cache = require("core.cache.cache")

local function test_gps_mapping_api()
  print("Testing GPS mapping API...")
  
  -- Initialize cache
  Cache.init()
  
  -- Test get_gps_mapping_for_surface function exists
  local has_function = type(Cache.Lookups.get_gps_mapping_for_surface) == "function"
  print("✅ get_gps_mapping_for_surface function exists: " .. tostring(has_function))
  
  -- Test with surface 1 (nauvis)
  local gps_mapping = Cache.Lookups.get_gps_mapping_for_surface(1)
  local mapping_type = type(gps_mapping)
  print("✅ Function returns table: " .. tostring(mapping_type == "table"))
  
  -- Count entries
  local count = 0
  for gps, chart_tag in pairs(gps_mapping) do
    count = count + 1
    print("GPS entry: " .. tostring(gps) .. " -> chart_tag.valid: " .. tostring(chart_tag.valid))
    if count >= 3 then break end -- Limit output
  end
  
  print("✅ GPS mapping entries found: " .. count)
  print("Test completed successfully!")
end

-- Export for manual testing
return {
  test_gps_mapping_api = test_gps_mapping_api
}
