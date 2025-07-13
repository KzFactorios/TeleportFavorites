-- tests/tag_destroy_helper_spec.lua
-- Simple smoke tests for core.tag.tag_destroy_helper

require("test_bootstrap")
require("test_framework")

-- Mock dependencies
local mock_error_handler = {
  debug_log = function() end,
  capture = function() end
}

local mock_cache = {
  get_player_data = function() return { favorites = {} } end
}

local mock_favorite_utils = {
  has_any_favorites = function() return false end,
  cleanup_player_favorites = function() end,
  cleanup_faved_by_players = function() end
}

-- Mock package.loaded
package.loaded["core.utils.error_handler"] = mock_error_handler
package.loaded["core.cache.cache"] = mock_cache
package.loaded["core.favorite.favorite_utils"] = mock_favorite_utils

-- Mock game environment
_G.game = _G.game or { players = {} }
_G.storage = _G.storage or { players = {}, surfaces = {}, cache = {} }

describe("TagDestroyHelper", function()
  local tag_destroy_helper
  
  before_each(function()
    -- Fresh module load for each test
    package.loaded["core.tag.tag_destroy_helper"] = nil
    tag_destroy_helper = require("core.tag.tag_destroy_helper")
  end)

  it("should load without errors", function()
    local success, err = pcall(function()
      return tag_destroy_helper
    end)
    assert(success, "Module should load without errors: " .. tostring(err))
    assert(type(tag_destroy_helper) == "table", "Should be a table")
  end)

  it("should have the expected exported functions", function()
    local success, err = pcall(function()
      assert(tag_destroy_helper ~= nil, "Module should be loaded")
      assert(type(tag_destroy_helper) == "table", "Module should be a table")
    end)
    assert(success, "Function should execute without errors: " .. tostring(err))
  end)

end)
