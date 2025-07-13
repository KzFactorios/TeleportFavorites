local test_framework = require("tests.test_framework")

-- Mock all dependencies first
package.loaded["core.utils.error_handler"] = {
  debug_log = function(msg, data) end
}

package.loaded["core.utils.gps_utils"] = {
  gps_string_to_table = function(gps)
    return {x = 100, y = 200, surface = 1}
  end,
  table_to_gps_string = function(pos)
    return "100.200.1"
  end
}

package.loaded["core.cache.cache"] = {
  Lookups = {
    get_chart_tag_cache = function(surface_index)
      return {{valid = true, position = {x = 100, y = 200}}}
    end,
    invalidate_surface_chart_tags = function(surface_index) end
  }
}

package.loaded["core.utils.settings_access"] = {
  get_settings = function() return {} end,
  get_chart_tag_click_radius = function() return 5 end
}

-- Mock defines global
defines = {
  render_mode = {
    chart = 1
  }
}

local ChartTagUtils = require("core.utils.chart_tag_utils")

describe("ChartTagUtils", function()
  it("should execute find_closest_chart_tag_to_position without errors", function()
    local mock_player = {
      valid = true,
      render_mode = 1, -- defines.render_mode.chart
      surface = {index = 1}
    }
    local mock_position = {x = 100, y = 200}
    
    local success, err = pcall(function()
      ChartTagUtils.find_closest_chart_tag_to_position(mock_player, mock_position)
    end)
    assert(success, "find_closest_chart_tag_to_position should execute without errors: " .. tostring(err))
  end)
  
  it("should handle nil player gracefully", function()
    local mock_position = {x = 100, y = 200}
    
    local success, err = pcall(function()
      ChartTagUtils.find_closest_chart_tag_to_position(nil, mock_position)
    end)
    assert(success, "find_closest_chart_tag_to_position should handle nil player: " .. tostring(err))
  end)
  
  it("should handle nil position gracefully", function()
    local mock_player = {
      valid = true,
      render_mode = 1,
      surface = {index = 1}
    }
    
    local success, err = pcall(function()
      ChartTagUtils.find_closest_chart_tag_to_position(mock_player, nil)
    end)
    assert(success, "find_closest_chart_tag_to_position should handle nil position: " .. tostring(err))
  end)
  
  it("should handle invalid player gracefully", function()
    local mock_player = {valid = false}
    local mock_position = {x = 100, y = 200}
    
    local success, err = pcall(function()
      ChartTagUtils.find_closest_chart_tag_to_position(mock_player, mock_position)
    end)
    assert(success, "find_closest_chart_tag_to_position should handle invalid player: " .. tostring(err))
  end)
  
  it("should handle player not in chart mode gracefully", function()
    local mock_player = {
      valid = true,
      render_mode = 0, -- not chart mode
      surface = {index = 1}
    }
    local mock_position = {x = 100, y = 200}
    
    local success, err = pcall(function()
      ChartTagUtils.find_closest_chart_tag_to_position(mock_player, mock_position)
    end)
    assert(success, "find_closest_chart_tag_to_position should handle non-chart mode: " .. tostring(err))
  end)
end)
