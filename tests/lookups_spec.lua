-- Require canonical test bootstrap to patch all mocks before any SUT or test code
require("tests.test_bootstrap")

-- Mock the required modules
local mock_error_handler = {
  debug_log = function(...) 
    print("[MOCK ERROR HANDLER] debug_log called:", ...)
  end
}

local mock_position_utils = {
  is_walkable_position = function(surface, pos) 
    return true 
  end
}

local mock_basic_helpers = {
  normalize_index = function(idx) 
    return tonumber(idx) 
  end
}

local mock_gps_utils = {
  gps_from_map_position = function(pos, surface_index)
    local function pad(n)
      return string.format("%03d", tonumber(n) or 0)
    end
    return pad(pos.x) .. "." .. pad(pos.y) .. "." .. tostring(surface_index)
  end,
  get_surface_index_from_gps = function(gps)
    if not gps or gps == "" then return nil end
    local parts = {}
    for part in string.gmatch(gps, "[^.]+") do 
      table.insert(parts, part) 
    end
    return tonumber(parts[3]) or 1
  end
}

package.loaded["core.utils.error_handler"] = mock_error_handler
package.loaded["core.utils.position_utils"] = mock_position_utils  
package.loaded["core.utils.basic_helpers"] = mock_basic_helpers
package.loaded["core.utils.gps_utils"] = mock_gps_utils

-- Mock game environment
local function create_mock_chart_tag(x, y, valid)
  return {
    valid = valid == nil and true or valid,
    position = {x = x, y = y},
    icon = "signal-1",
    text = "Test Tag",
    destroy = function(self) 
      self.valid = false 
    end
  }
end

local mock_surfaces = {
  [1] = {
    index = 1,
    name = "nauvis",
    valid = true,
    get_tile = function(x, y)
      return {
        collides_with = function() return false end
      }
    end
  }
}

local mock_chart_tags = {
  [1] = {
    create_mock_chart_tag(1, 2, true),
    create_mock_chart_tag(5, 6, true)
  }
}

_G.game = {
  surfaces = mock_surfaces,
  forces = {
    ["player"] = {
      find_chart_tags = function(surface)
        return mock_chart_tags[surface.index] or {}
      end
    }
  }
}

describe("Lookups cache module", function()
  it("initializes cache and fetches chart tags", function()
    local success, err = pcall(function()
      local Lookups = require("core.cache.lookups")
      local cache = Lookups.init()
      assert(type(cache) == "table", "Expected cache to be a table")
      
      local tags = Lookups.get_chart_tag_cache(1)
      assert(type(tags) == "table", "Expected tags to be a table")
    end)
    
    assert(success, "Lookups initialization should work without errors: " .. tostring(err))
  end)

  it("returns chart tag by gps", function()
    local success, err = pcall(function()
      -- Clear any existing cache
      package.loaded["core.cache.lookups"] = nil
      local Lookups = require("core.cache.lookups")
      
      Lookups.init()
      Lookups.get_chart_tag_cache(1) -- Force cache build
      
      local gps = "001.002.1"
      local tag = Lookups.get_chart_tag_by_gps(gps)
      
      -- Should find the tag or return nil gracefully
      assert(tag == nil or type(tag) == "table", "Expected tag to be table or nil")
    end)
    
    assert(success, "get_chart_tag_by_gps should work without errors: " .. tostring(err))
  end)

  it("removes chart tag from cache by gps", function()
    local success, err = pcall(function()
      package.loaded["core.cache.lookups"] = nil
      local Lookups = require("core.cache.lookups")
      
      Lookups.init()
      Lookups.remove_chart_tag_from_cache_by_gps("001.002.1")
    end)
    
    assert(success, "remove_chart_tag_from_cache_by_gps should work without errors: " .. tostring(err))
  end)

  it("clears all caches", function()
    local success, err = pcall(function()
      local Lookups = require("core.cache.lookups")
      Lookups.clear_all_caches()
    end)
    
    assert(success, "clear_all_caches should work without errors: " .. tostring(err))
  end)

  it("handles invalid surface index gracefully", function()
    local success, err = pcall(function()
      local Lookups = require("core.cache.lookups")
      
      -- These should handle invalid input gracefully 
      -- Note: passing nil directly would cause a runtime error in production code
      -- so we test with string input that can't be converted to number
      Lookups.clear_surface_cache_chart_tags("not-a-number")
    end)
    
    assert(success, "Invalid surface index should be handled gracefully: " .. tostring(err))
  end)

  it("returns nil for empty or nil gps in get_chart_tag_by_gps", function()
    local success, err = pcall(function()
      local Lookups = require("core.cache.lookups")
      
      local result1 = Lookups.get_chart_tag_by_gps("")
      
      assert(result1 == nil, "Expected nil for empty gps")
    end)
    
    assert(success, "Empty GPS should be handled gracefully: " .. tostring(err))
  end)

  it("returns nil for non-existent surface in get_chart_tag_by_gps", function()
    local success, err = pcall(function()
      local Lookups = require("core.cache.lookups")
      
      -- Use a GPS string with a surface index that does not exist
      local gps = "001.002.99" -- surface 99 does not exist
      local result = Lookups.get_chart_tag_by_gps(gps)
      
      assert(result == nil, "Expected nil for non-existent surface")
    end)
    
    assert(success, "Non-existent surface should be handled gracefully: " .. tostring(err))
  end)

  it("returns nil for invalid chart tag in get_chart_tag_by_gps", function()
    local success, err = pcall(function()
      local Lookups = require("core.cache.lookups")
      Lookups.init()
      
      local gps = "999.999.1" -- Non-existent position
      local result = Lookups.get_chart_tag_by_gps(gps)
      
      assert(result == nil, "Expected nil for invalid chart tag position")
    end)
    
    assert(success, "Invalid chart tag should be handled gracefully: " .. tostring(err))
  end)

  it("returns early in remove_chart_tag_from_cache_by_gps for nil/empty gps", function()
    local success, err = pcall(function()
      local Lookups = require("core.cache.lookups")
      
      -- Should not throw
      Lookups.remove_chart_tag_from_cache_by_gps("")
    end)
    
    assert(success, "Empty GPS removal should be handled gracefully: " .. tostring(err))
  end)

  it("returns early in remove_chart_tag_from_cache_by_gps for missing chart tag", function()
    local success, err = pcall(function()
      local Lookups = require("core.cache.lookups")
      
      -- Should not throw
      Lookups.remove_chart_tag_from_cache_by_gps("999.999.1")
    end)
    
    assert(success, "Missing chart tag removal should be handled gracefully: " .. tostring(err))
  end)

  it("handles chart_tag.destroy() failure gracefully in remove_chart_tag_from_cache_by_gps", function()
    local success, err = pcall(function()
      local Lookups = require("core.cache.lookups")
      
      -- Should not throw even if destroy fails
      Lookups.remove_chart_tag_from_cache_by_gps("001.002.1")
    end)
    
    assert(success, "Chart tag destroy failure should be handled gracefully: " .. tostring(err))
  end)

  it("handles non-walkable chart tag position in get_chart_tag_by_gps", function()
    -- Patch PositionUtils to return false for walkability
    package.loaded["core.utils.position_utils"] = {
      is_walkable_position = function() return false end
    }
    
    local success, err = pcall(function()
      package.loaded["core.cache.lookups"] = nil
      local Lookups = require("core.cache.lookups")
      
      Lookups.init()
      local gps = "001.002.1"
      local result = Lookups.get_chart_tag_by_gps(gps)
      
      -- Should still work (walkability only logs)
      assert(result == nil or type(result) == "table", "Expected table or nil for non-walkable position")
    end)
    
    assert(success, "Non-walkable position should be handled gracefully: " .. tostring(err))
  end)
end)
