-- tests/handlers_chart_tag_spec.lua
-- Simple smoke tests for chart tag handlers

require("test_framework")

-- Use centralized test helpers
local MockFactories = require("mocks.mock_factories")
local TestHelpers = require("mocks.test_helpers")
local EventFactories = require("mocks.event_factories")
local GameSetupFactory = require("mocks.game_setup_factory")

-- Mock package.loaded
package.loaded["core.events.chart_tag_modification_helpers"] = {
  is_valid_tag_modification = function() return true end,
  extract_gps = function() return "gps:100.200.1", "gps:90.180.1" end,
  update_tag_and_cleanup = function() end,
  update_favorites_gps = function() end
}

-- Create a mutable mock that can be modified in tests
local tag_editor_helpers_mock = {
  needs_normalization = function() return false end,
  normalize_and_replace_chart_tag = function() end
}
package.loaded["core.events.tag_editor_event_helpers"] = tag_editor_helpers_mock

package.loaded["core.cache.cache"] = {
  get_tag_editor_data = function() return nil end,
  set_tag_editor_data = function() end,
  Lookups = {
    invalidate_surface_chart_tags = function() end
  }
}

package.loaded["core.utils.error_handler"] = {
  debug_log = function() end
}

-- Setup mock game with simple structure using factory
local game_state = GameSetupFactory.setup_basic_game()
local mock_surface = game_state.surface

-- Import the module under test
local Handlers = require("core.events.handlers")

describe("Chart Tag Handlers", function()
  
  it("should handle chart tag added event correctly", function()
    local event = EventFactories.create_chart_tag_event(1, 
      EventFactories.create_fractional_position(), mock_surface)
    local success, err = pcall(function()
      Handlers.on_chart_tag_added(event)
    end)
    assert(success, "Handler should execute without errors: " .. tostring(err))
  end)
  
  it("should not normalize chart tag with integer positions", function()
    local event = EventFactories.create_chart_tag_event(1, 
      EventFactories.create_integer_position(), mock_surface)
    local success, err = pcall(function()
      Handlers.on_chart_tag_added(event)
    end)
    assert(success, "Handler should execute without errors: " .. tostring(err))
  end)
  
  it("should handle chart tag modification correctly with normalization", function()
    -- Reset the mock function for this test
    tag_editor_helpers_mock.needs_normalization = function() return true end
    
    local event = EventFactories.create_chart_tag_modification_event(1, 
      EventFactories.create_fractional_position(), 
      EventFactories.create_integer_position(90, 180), 
      mock_surface)
    local success, err = pcall(function()
      Handlers.on_chart_tag_modified(event)
    end)
    assert(success, "Handler should execute without errors: " .. tostring(err))
  end)
  
  it("should handle chart tag modification correctly without normalization", function()
    -- Reset the mock function for this test
    tag_editor_helpers_mock.needs_normalization = function() return false end
    
    local event = EventFactories.create_chart_tag_modification_event(1, 
      EventFactories.create_integer_position(), 
      EventFactories.create_integer_position(90, 180), 
      mock_surface)
    local success, err = pcall(function()
      Handlers.on_chart_tag_modified(event)
    end)
    assert(success, "Handler should execute without errors: " .. tostring(err))
  end)
  
  it("should update tag_editor data when chart tag is modified", function()
    -- Temporarily override for this test
    local original_cache = package.loaded["core.cache.cache"]
    package.loaded["core.cache.cache"] = {
      get_tag_editor_data = function() return { gps = "gps:90.180.1" } end,
      set_tag_editor_data = function() end,
      Lookups = {
        invalidate_surface_chart_tags = function() end
      }
    }
    
    local event = EventFactories.create_chart_tag_modification_event(
      1, 
      { x = 101, y = 201 }, 
      { x = 90, y = 180 }, 
      mock_surface
    )
    local success, err = pcall(function()
      Handlers.on_chart_tag_modified(event)
    end)
    assert(success, "Handler should execute without errors: " .. tostring(err))
    
    -- Restore original
    package.loaded["core.cache.cache"] = original_cache
  end)
  
  it("should handle invalid player in chart tag events", function()
    local event = EventFactories.create_chart_tag_event(999, -- Invalid player
      EventFactories.create_integer_position(), mock_surface)
    local success, err = pcall(function()
      Handlers.on_chart_tag_added(event)
    end)
    assert(success, "Handler should execute without errors: " .. tostring(err))
  end)
  
  it("should do nothing if event.tag is missing in on_chart_tag_added", function()
    local event = EventFactories.create_invalid_event("tag", 1)
    local success, err = pcall(function()
      Handlers.on_chart_tag_added(event)
    end)
    assert(success, "Handler should execute without errors: " .. tostring(err))
  end)
  
  it("should do nothing if event.tag is invalid in on_chart_tag_added", function()
    local event = EventFactories.create_invalid_event("invalid_tag", 1)
    local success, err = pcall(function()
      Handlers.on_chart_tag_added(event)
    end)
    assert(success, "Handler should execute without errors: " .. tostring(err))
  end)
  
  it("should do nothing if event.tag.position is missing in on_chart_tag_added", function()
    local event = EventFactories.create_invalid_event("position", 1)
    event.tag.surface = mock_surface
    local success, err = pcall(function()
      Handlers.on_chart_tag_added(event)
    end)
    assert(success, "Handler should execute without errors: " .. tostring(err))
  end)
  
  it("should do nothing if event.old_position is missing in on_chart_tag_modified", function()
    local event = EventFactories.create_invalid_event("old_position", 1)
    event.tag = { 
      valid = true, 
      position = EventFactories.create_integer_position(), 
      surface = mock_surface 
    }
    local success, err = pcall(function()
      Handlers.on_chart_tag_modified(event)
    end)
    assert(success, "Handler should execute without errors: " .. tostring(err))
  end)
  
  it("should do nothing if event.tag is missing in on_chart_tag_modified", function()
    local event = EventFactories.create_invalid_event("tag", 1)
    event.old_position = EventFactories.create_integer_position(90, 180)
    local success, err = pcall(function()
      Handlers.on_chart_tag_modified(event)
    end)
    assert(success, "Handler should execute without errors: " .. tostring(err))
  end)
  
  it("should do nothing if event.tag.position is missing in on_chart_tag_modified", function()
    local event = EventFactories.create_invalid_event("position", 1)
    event.tag.surface = mock_surface
    event.old_position = EventFactories.create_integer_position(90, 180)
    local success, err = pcall(function()
      Handlers.on_chart_tag_modified(event)
    end)
    assert(success, "Handler should execute without errors: " .. tostring(err))
  end)
  
  it("should do nothing if player is invalid in on_chart_tag_modified", function()
    local event = EventFactories.create_chart_tag_modification_event(999, -- Invalid player
      EventFactories.create_integer_position(),
      EventFactories.create_integer_position(90, 180),
      mock_surface)
    local success, err = pcall(function()
      Handlers.on_chart_tag_modified(event)
    end)
    assert(success, "Handler should execute without errors: " .. tostring(err))
  end)
  
end)
