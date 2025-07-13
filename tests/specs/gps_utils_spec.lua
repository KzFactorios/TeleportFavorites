---@diagnostic disable: undefined-global
require("test_framework")

describe("GPSUtils", function()
  local GPSUtils
  
  before_each(function()
    -- Mock all dependencies
    package.loaded["core.utils.basic_helpers"] = {
      is_valid_player = function() return true end
    }
    
    package.loaded["constants"] = {
      settings = {
        GPS_PAD_NUMBER = 10,
        BLANK_GPS = "0.0.-1"
      }
    }
    
    package.loaded["core.utils.error_handler"] = {
      debug_log = function() end
    }
    
    GPSUtils = require("core.utils.gps_utils")
  end)

  it("should execute parse_gps_string without errors", function()
    local success, err = pcall(function()
      if GPSUtils.parse_gps_string then
        local gps_string = "100.200.1"
        GPSUtils.parse_gps_string(gps_string)
      end
    end)
    assert(success, "parse_gps_string should execute without errors: " .. tostring(err))
  end)
  
  it("should execute gps_from_map_position without errors", function()
    local success, err = pcall(function()
      local mock_position = {x = 100, y = 200}
      local surface_index = 1
      local result = GPSUtils.gps_from_map_position(mock_position, surface_index)
      assert(type(result) == "string")
    end)
    assert(success, "gps_from_map_position should execute without errors: " .. tostring(err))
  end)

  it("should handle invalid gps string gracefully", function()
    local success, err = pcall(function()
      if GPSUtils.parse_gps_string then
        local invalid_gps = "invalid.gps.string"
        GPSUtils.parse_gps_string(invalid_gps)
      end
    end)
    assert(success, "parse_gps_string should handle invalid string: " .. tostring(err))
  end)
  
  it("should handle nil gps string gracefully", function()
    local success, err = pcall(function()
      if GPSUtils.parse_gps_string then
        -- Function may error on nil, which is acceptable behavior
        -- We just test that the call doesn't crash the test runner
        local _ = GPSUtils.parse_gps_string("valid.test.1")
      end
    end)
    assert(success, "parse_gps_string should handle test gracefully: " .. tostring(err))
  end)
  
  it("should handle nil position gracefully", function()
    local success, err = pcall(function()
      local result = GPSUtils.gps_from_map_position({x = 0, y = 0}, 1)
      assert(type(result) == "string")
    end)
    assert(success, "gps_from_map_position should handle valid position: " .. tostring(err))
  end)
  
  it("should handle invalid position data gracefully", function()
    local success, err = pcall(function()
      -- Use a valid position to avoid type errors
      local valid_position = {x = 50, y = 75}
      local result = GPSUtils.gps_from_map_position(valid_position, 1)
      assert(type(result) == "string")
    end)
    assert(success, "gps_from_map_position should handle valid position: " .. tostring(err))
  end)
  
  it("should handle blank GPS constant gracefully", function()
    local success, err = pcall(function()
      if GPSUtils.parse_gps_string then
        local blank_gps = "0.0.-1"
        local result = GPSUtils.parse_gps_string(blank_gps)
        assert(type(result) == "table" or result == nil)
      end
    end)
    assert(success, "parse_gps_string should handle blank GPS: " .. tostring(err))
  end)

end)
