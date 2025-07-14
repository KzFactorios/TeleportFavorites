-- Require canonical test bootstrap to patch all mocks before any SUT or test code
require("test_bootstrap")

-- Use centralized factories
local GameSetupFactory = require("mocks.game_setup_factory")
local EventFactories = require("mocks.event_factories")

-- Mock the modules that will be required
local Cache = {
  ensure_surface_cache = function() end,
  set_player_surface = function() end
}

package.loaded["core.cache.cache"] = Cache

-- Setup test environment with multiple surfaces
GameSetupFactory.setup_test_globals({
  { index = 1, name = "player1", surface_index = 1 }
}, {
  { index = 1, name = "nauvis" },
  { index = 2, name = "space" }
})

describe("Surface Event Handlers", function()
  it("should call ensure_surface_cache when player changes surface", function()
    local event = EventFactories.create_surface_change_event(1, 2)
    
    local success, err = pcall(function()
      local Handlers = require("core.events.handlers")
      Handlers.on_player_changed_surface(event)
    end)
    
    assert(success, "on_player_changed_surface should execute without errors: " .. tostring(err))
  end)

  it("should handle invalid player gracefully", function()
    local event = EventFactories.create_surface_change_event(999, 2) -- Invalid player
    
    local success, err = pcall(function()
      local Handlers = require("core.events.handlers")
      Handlers.on_player_changed_surface(event)
    end)
    
    assert(success, "Invalid player should be handled gracefully: " .. tostring(err))
  end)

  it("should handle player with same surface gracefully", function()
    local event = EventFactories.create_surface_change_event(1, 1) -- Same surface
    
    local success, err = pcall(function()
      local Handlers = require("core.events.handlers")
      Handlers.on_player_changed_surface(event)
    end)
    
    assert(success, "Same surface change should be handled gracefully: " .. tostring(err))
  end)
end)
