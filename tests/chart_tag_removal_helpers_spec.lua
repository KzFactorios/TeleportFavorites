local test_framework = require("tests.test_framework")

-- Mock all dependencies first
package.loaded["core.cache.cache"] = {
  remove_tag_from_cache = function(gps) end,
  Lookups = {
    get_all_players_with_favorite = function(gps)
      return {{index = 1, valid = true}}
    end
  }
}

package.loaded["core.utils.gps_utils"] = {
  position_to_gps_string = function(position)
    return "100.200.1"
  end
}

package.loaded["core.utils.game_helpers"] = {
  player_print = function(player, message) end
}

package.loaded["core.utils.admin_utils"] = {
  is_admin = function(player) return false end
}

package.loaded["core.utils.chart_tag_spec_builder"] = {
  build_tag_spec = function(gps, text, icon)
    return {text = text, icon = icon, position = {x = 100, y = 200}}
  end
}

package.loaded["core.utils.chart_tag_utils"] = {
  create_chart_tag = function(player, surface, spec)
    return {valid = true}
  end
}

package.loaded["core.utils.rich_text_formatter"] = {
  format_message = function(template, params) return "formatted message" end
}

local ChartTagRemovalHelpers = require("core.events.chart_tag_removal_helpers")

describe("ChartTagRemovalHelpers", function()
  it("should execute validate_removal_event without errors", function()
    local mock_event = {
      tag = {
        valid = true,
        text = "test tag",
        icon = {name = "item/iron-ore"}
      }
    }
    
    local success, err = pcall(function()
      ChartTagRemovalHelpers.validate_removal_event(mock_event)
    end)
    assert(success, "validate_removal_event should execute without errors: " .. tostring(err))
  end)
  
  it("should handle invalid event gracefully", function()
    local success, err = pcall(function()
      ChartTagRemovalHelpers.validate_removal_event(nil)
    end)
    assert(success, "validate_removal_event should handle nil event: " .. tostring(err))
  end)
  
  it("should handle event with invalid tag gracefully", function()
    local mock_event = {
      tag = {valid = false}
    }
    
    local success, err = pcall(function()
      ChartTagRemovalHelpers.validate_removal_event(mock_event)
    end)
    assert(success, "validate_removal_event should handle invalid tag: " .. tostring(err))
  end)
  
  it("should handle event with missing tag gracefully", function()
    local mock_event = {}
    
    local success, err = pcall(function()
      ChartTagRemovalHelpers.validate_removal_event(mock_event)
    end)
    assert(success, "validate_removal_event should handle missing tag: " .. tostring(err))
  end)
end)
