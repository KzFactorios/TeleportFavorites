-- Test script for lookups data retrieval in data viewer
-- This file helps validate that the lookups tab shows meaningful data

local test_lookups_data = {}

-- Mock game environment for testing
local mock_game = {
  surfaces = {
    [1] = { name = "nauvis", valid = true, index = 1 },
    [2] = { name = "test-surface", valid = true, index = 2 }
  }
}

-- Mock Cache for testing
local mock_cache = {
  Lookups = {
    get_chart_tag_cache = function(surface_index)
      -- Simulate different scenarios
      if surface_index == 1 then
        return {
          { position = {x = 0, y = 0}, text = "Test Tag 1" },
          { position = {x = 10, y = 10}, text = "Test Tag 2" }
        }
      elseif surface_index == 2 then
        return {} -- Empty surface
      end
      return {}
    end
  },
  init = function() end
}

-- Test function to simulate get_lookup_data behavior
function test_lookups_data.simulate_lookup_data_retrieval()
  print("Testing lookup data retrieval...")
  
  -- Simulate empty global cache scenario
  _G["Lookups"] = nil
  
  local populated_data = { surfaces = {} }
  
  for surface_index, surface in pairs(mock_game.surfaces) do
    if surface and surface.valid then
      local chart_tags = mock_cache.Lookups.get_chart_tag_cache(surface.index)
      if chart_tags and #chart_tags > 0 then
        populated_data.surfaces[surface_index] = {
          surface_name = surface.name,
          chart_tag_count = #chart_tags,
          chart_tags = chart_tags
        }
      end
    end
  end
  
  if next(populated_data.surfaces) == nil then
    populated_data.info = "No chart tags found on any surface"
    populated_data.cache_status = "empty_or_uninitialized"
  else
    populated_data.cache_status = "populated_from_live_data"
    populated_data.total_surfaces_with_tags = 0
    for _ in pairs(populated_data.surfaces) do
      populated_data.total_surfaces_with_tags = populated_data.total_surfaces_with_tags + 1
    end
  end
  
  print("Result:")
  print("  Surfaces with data: " .. (populated_data.total_surfaces_with_tags or 0))
  print("  Cache status: " .. (populated_data.cache_status or "unknown"))
  
  return populated_data
end

return test_lookups_data
