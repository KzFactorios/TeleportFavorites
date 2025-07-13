local test_framework = require("test_framework")

-- Mock all dependencies first
package.loaded["core.utils.gui_validation"] = {
  is_valid_gui_element = function(element) return true end
}

package.loaded["gui.gui_base"] = {
  create_element = function(spec) 
    return {valid = true, add = function() return {valid = true} end}
  end
}

package.loaded["core.utils.gps_utils"] = {
  gps_string_to_table = function(gps)
    return {x = 100, y = 200, surface = 1}
  end
}

local GuiHelpers = require("core.utils.gui_helpers")

describe("GuiHelpers", function()
  it("should execute get_or_create_gui_flow_from_gui_top without errors", function()
    local mock_player = {
      gui = {
        top = {
          tf_main_gui_flow = {valid = true},
          add = function(spec) return {valid = true} end
        }
      }
    }
    
    local success, err = pcall(function()
      GuiHelpers.get_or_create_gui_flow_from_gui_top(mock_player)
    end)
    assert(success, "get_or_create_gui_flow_from_gui_top should execute without errors: " .. tostring(err))
  end)
  
  it("should execute build_favorite_tooltip without errors", function()
    local mock_fav = {
      gps = "100.200.1",
      tag = {
        chart_tag = {text = "test tag"}
      }
    }
    
    local success, err = pcall(function()
      GuiHelpers.build_favorite_tooltip(mock_fav)
    end)
    assert(success, "build_favorite_tooltip should execute without errors: " .. tostring(err))
  end)
  
  it("should handle nil favorite in build_favorite_tooltip gracefully", function()
    local success, err = pcall(function()
      GuiHelpers.build_favorite_tooltip(nil)
    end)
    assert(success, "build_favorite_tooltip should handle nil favorite: " .. tostring(err))
  end)
  
  it("should handle missing gui elements gracefully", function()
    local mock_player = {
      gui = {
        top = {
          add = function(spec) return {valid = true} end
        }
      }
    }
    
    local success, err = pcall(function()
      GuiHelpers.get_or_create_gui_flow_from_gui_top(mock_player)
    end)
    assert(success, "get_or_create_gui_flow_from_gui_top should handle missing elements: " .. tostring(err))
  end)
  
  it("should handle build_favorite_tooltip with options gracefully", function()
    local mock_fav = {gps = "100.200.1"}
    local mock_opts = {max_len = 20, text = "custom text"}
    
    local success, err = pcall(function()
      GuiHelpers.build_favorite_tooltip(mock_fav, mock_opts)
    end)
    assert(success, "build_favorite_tooltip should handle options: " .. tostring(err))
  end)
end)
