-- tests/tag_destroy_helper_spec.lua
-- Combined and deduplicated tests for core.tag.tag_destroy_helper

require("tests.test_framework")

-- CRITICAL: Set test exposure flag BEFORE any requires
_G._TEST_EXPOSE_TAG_DESTROY_HELPERS = true

-- Setup test environment 
_G.global = _G.global or {}
_G.storage = _G.storage or { players = {}, surfaces = {}, cache = {} }
_G.game = _G.game or { players = {} }
_G.surfaces = _G.surfaces or {}

-- Setup required mocks
_G.FavoriteUtils = require("tests.mocks.favorite_utils_mock")
package.loaded["core.favorite.favorite_utils"] = _G.FavoriteUtils

local ErrorHandler = require("core.utils.error_handler")
local Cache = require("core.cache.cache")
local spy_utils = require("tests.mocks.spy_utils")
local make_spy = spy_utils.make_spy

-- Use describe to set test exposure flag in isolation
describe("TagDestroyHelper", function()
  local tag_destroy_helper
  local helpers
  
  before_each(function()
    -- Ensure test exposure flag is set
    _G._TEST_EXPOSE_TAG_DESTROY_HELPERS = true
    
    -- Require the module fresh each time
    package.loaded["core.tag.tag_destroy_helper"] = nil
    tag_destroy_helper = require("core.tag.tag_destroy_helper")
    helpers = tag_destroy_helper._test_expose
    
    -- Verify test exposure worked
    if not helpers then
      error("CRITICAL: Test exposure failed - helpers is nil, _test_expose = " .. tostring(tag_destroy_helper._test_expose))
    end
  end)

  it("should detect tag being destroyed to prevent infinite recursion", function()
    local tag = { gps = "100.200.1" }
    if tag_destroy_helper.is_tag_being_destroyed(tag) then
      error("Expected is_tag_being_destroyed to return false")
    end
  end)

  it("should validate has_any_favorites function", function()
    if helpers.has_any_favorites(nil) then
      error("Expected has_any_favorites(nil) to return false")
    end
    if helpers.has_any_favorites({}) then
      error("Expected has_any_favorites({}) to return false")
    end
    if helpers.has_any_favorites({faved_by_players = nil}) then
      error("Expected has_any_favorites({faved_by_players = nil}) to return false")
    end
    if helpers.has_any_favorites({faved_by_players = {}}) then
      error("Expected has_any_favorites({faved_by_players = {}}) to return false")
    end
    
    -- Has favorites
    if not helpers.has_any_favorites({faved_by_players = {1}}) then
      error("Expected has_any_favorites({faved_by_players = {1}}) to return true")
    end
  end)

  it("should validate destruction inputs", function()
    local ok, issues = helpers.validate_destruction_inputs({}, nil)
    if ok then
      error("Expected validate_destruction_inputs({}, nil) to return false")
    end
    if type(issues) ~= "table" or #issues == 0 or issues[1] ~= "Tag missing GPS coordinate" then
      error("Expected issues[1] to be 'Tag missing GPS coordinate', got: " .. tostring(issues and issues[1] or issues))
    end
    
    local chart_tag = { valid = true }
    local ok, issues = helpers.validate_destruction_inputs({ gps = "1.2.3" }, chart_tag)
    if not ok then
      error("Expected validate_destruction_inputs({ gps = '1.2.3' }, chart_tag) to return true")
    end
    if issues == nil or #issues ~= 0 then
      error("Expected issues to be empty table, got: " .. tostring(issues))
    end
  end)
end)
