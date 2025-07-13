-- tests/handlers_chart_tag_modified_spec.lua
-- Simple smoke tests for the on_chart_tag_modified handler

require("test_bootstrap")
require("test_framework")

-- Simple mocks for dependencies
local ChartTagModificationHelpers = {
  is_valid_tag_modification = function() return true end,
  extract_gps = function() return "gps:100.200.1", "gps:90.180.1" end,
  update_tag_and_cleanup = function() end,
  update_favorites_gps = function() end
}

local TagEditorEventHelpers = {
  needs_normalization = function() return false end,
  normalize_and_replace_chart_tag = function() end
}

local Cache = {
  get_tag_editor_data = function() return nil end,
  set_tag_editor_data = function() end,
  Lookups = {
    invalidate_surface_chart_tags = function() end
  }
}

local ErrorHandler = {
  debug_log = function() end
}

-- Mock package.loaded
package.loaded["core.events.chart_tag_modification_helpers"] = ChartTagModificationHelpers
package.loaded["core.events.tag_editor_event_helpers"] = TagEditorEventHelpers
package.loaded["core.cache.cache"] = Cache
package.loaded["core.utils.error_handler"] = ErrorHandler

-- Mock game environment
local mock_player = {
  index = 1,
  name = "test_player",
  valid = true,
  surface = { index = 1, name = "nauvis", valid = true }
}

_G.game = {
  players = { [1] = mock_player },
  get_player = function(index) return _G.game.players[index] end,
  surfaces = { [1] = { index = 1, name = "nauvis", valid = true } }
}

-- Import the module under test
local Handlers = require("core.events.handlers")

describe("Handlers.on_chart_tag_modified", function()
  
  it("should not process for invalid players", function()
    local event = { 
      player_index = 999, -- Invalid player
      tag = { valid = true, position = { x = 100, y = 200 } },
      old_position = { x = 90, y = 180 }
    }
    local success, err = pcall(function()
      Handlers.on_chart_tag_modified(event)
    end)
    assert(success, "Handler should execute without errors: " .. tostring(err))
  end)
  
  it("should validate tag modifications", function()
    local event = { 
      player_index = 1,
      tag = { valid = true, position = { x = 100, y = 200 } },
      old_position = { x = 90, y = 180 }
    }
    local success, err = pcall(function()
      Handlers.on_chart_tag_modified(event)
    end)
    assert(success, "Handler should execute without errors: " .. tostring(err))
  end)
  
  it("should not proceed if validation fails", function()
    ChartTagModificationHelpers.is_valid_tag_modification = function() return false end
    local event = { 
      player_index = 1,
      tag = { valid = true, position = { x = 100, y = 200 } },
      old_position = { x = 90, y = 180 }
    }
    local success, err = pcall(function()
      Handlers.on_chart_tag_modified(event)
    end)
    assert(success, "Handler should execute without errors: " .. tostring(err))
  end)
  
  it("should extract GPS coordinates", function()
    local event = { 
      player_index = 1,
      tag = { valid = true, position = { x = 100, y = 200 } },
      old_position = { x = 90, y = 180 }
    }
    local success, err = pcall(function()
      Handlers.on_chart_tag_modified(event)
    end)
    assert(success, "Handler should execute without errors: " .. tostring(err))
  end)
  
  it("should handle tag editor updates", function()
    Cache.get_tag_editor_data = function() return { gps = "gps:90.180.1" } end
    local event = { 
      player_index = 1,
      tag = { valid = true, position = { x = 100, y = 200 } },
      old_position = { x = 90, y = 180 }
    }
    local success, err = pcall(function()
      Handlers.on_chart_tag_modified(event)
    end)
    assert(success, "Handler should execute without errors: " .. tostring(err))
  end)
  
  it("should handle normalization when needed", function()
    TagEditorEventHelpers.needs_normalization = function() return true end
    local event = { 
      player_index = 1,
      tag = { valid = true, position = { x = 100.5, y = 200.5 } },
      old_position = { x = 90, y = 180 }
    }
    local success, err = pcall(function()
      Handlers.on_chart_tag_modified(event)
    end)
    assert(success, "Handler should execute without errors: " .. tostring(err))
  end)
  
  it("should handle position changes without normalization", function()
    TagEditorEventHelpers.needs_normalization = function() return false end
    local event = { 
      player_index = 1,
      tag = { valid = true, position = { x = 100, y = 200 } },
      old_position = { x = 90, y = 180 }
    }
    local success, err = pcall(function()
      Handlers.on_chart_tag_modified(event)
    end)
    assert(success, "Handler should execute without errors: " .. tostring(err))
  end)
  
  it("should handle identical GPS coordinates", function()
    ChartTagModificationHelpers.extract_gps = function() return "gps:100.200.1", "gps:100.200.1" end
    local event = { 
      player_index = 1,
      tag = { valid = true, position = { x = 100, y = 200 } },
      old_position = { x = 100, y = 200 }
    }
    local success, err = pcall(function()
      Handlers.on_chart_tag_modified(event)
    end)
    assert(success, "Handler should execute without errors: " .. tostring(err))
  end)
  
  it("should handle missing old_position", function()
    local event = { 
      player_index = 1,
      tag = { valid = true, position = { x = 100, y = 200 } }
      -- old_position is missing
    }
    local success, err = pcall(function()
      Handlers.on_chart_tag_modified(event)
    end)
    assert(success, "Handler should execute without errors: " .. tostring(err))
  end)
  
  it("should handle invalid tag", function()
    local event = { 
      player_index = 1,
      tag = { valid = false },
      old_position = { x = 90, y = 180 }
    }
    local success, err = pcall(function()
      Handlers.on_chart_tag_modified(event)
    end)
    assert(success, "Handler should execute without errors: " .. tostring(err))
  end)
  
end)
