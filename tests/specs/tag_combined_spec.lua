-- tests/tag_combined_spec.lua
-- Simple smoke tests for core.tag.tag

require("test_bootstrap")
require("test_framework")

-- Mock dependencies
local mock_error_handler = {
  debug_log = function() end,
  capture = function() end
}

local mock_cache = {
  get_player_data = function() return { favorites = {} } end,
  get_tag_by_gps = function() return nil end,
  set_tag_by_gps = function() end
}

local mock_chart_tag_utils = {
  safe_add_chart_tag = function() return { valid = true, destroy = function() end } end,
  find_closest_chart_tag_to_position = function() return nil end
}

local mock_locale_utils = {
  get_tag_text = function() return "Test Tag" end
}

local mock_chart_tag_spec_builder = {
  build = function() return { position = {x=0, y=0}, text = "Test" } end
}

-- Mock package.loaded
package.loaded["core.utils.error_handler"] = mock_error_handler
package.loaded["core.cache.cache"] = mock_cache
package.loaded["core.utils.chart_tag_utils"] = mock_chart_tag_utils
package.loaded["core.utils.locale_utils"] = mock_locale_utils
package.loaded["core.utils.chart_tag_spec_builder"] = mock_chart_tag_spec_builder

-- Mock game environment
_G.game = _G.game or { players = {} }
_G.storage = _G.storage or { players = {}, surfaces = {}, cache = {} }

describe("Tag", function()
  local Tag
  
  before_each(function()
    -- Fresh module load for each test
    package.loaded["core.tag.tag"] = nil
    Tag = require("core.tag.tag")
  end)

  it("should load without errors", function()
    local success, err = pcall(function()
      assert(Tag ~= nil, "Module should be loaded")
      assert(type(Tag) == "table", "Module should be a table")
    end)
    assert(success, "Module should load without errors: " .. tostring(err))
  end)

  it("should be a valid module", function()
    local success, err = pcall(function()
      assert(Tag ~= nil, "Module should be loaded")
      assert(type(Tag) == "table", "Module should be a table")
    end)
    assert(success, "Module should load without errors: " .. tostring(err))
  end)

end)
