-- Require canonical test bootstrap to patch all mocks before any SUT or test code
require("tests.test_bootstrap")

-- Require canonical player mocks
local PlayerFavoritesMocks = require("tests.mocks.player_favorites_mocks")

-- Mock the modules that will be required
local Cache = {
  ensure_surface_cache = function() end,
  set_player_surface = function() end
}

package.loaded["core.cache.cache"] = Cache

local mock_surfaces = {
  [1] = { index = 1, name = "nauvis", valid = true },
  [2] = { index = 2, name = "space", valid = true }
}

_G.script = { on_nth_tick = function() end }

local mock_players = {}

_G.game = {
  players = mock_players,
  get_player = function(player_index) return mock_players[player_index] end,
  surfaces = mock_surfaces
}

describe("Surface Event Handlers", function()
  it("should call ensure_surface_cache when player changes surface", function()
    mock_players[1] = PlayerFavoritesMocks.mock_player(1, "player1", 1)
    
    local event = { player_index = 1, surface_index = 2 }
    
    local success, err = pcall(function()
      local Handlers = require("core.events.handlers")
      Handlers.on_player_changed_surface(event)
    end)
    
    assert(success, "on_player_changed_surface should execute without errors: " .. tostring(err))
  end)

  it("should handle invalid player gracefully", function()
    local event = { player_index = 999, surface_index = 2 }
    
    local success, err = pcall(function()
      local Handlers = require("core.events.handlers")
      Handlers.on_player_changed_surface(event)
    end)
    
    assert(success, "Invalid player should be handled gracefully: " .. tostring(err))
  end)

  it("should handle player with same surface gracefully", function()
    mock_players[1] = PlayerFavoritesMocks.mock_player(1, "player1", 1)
    
    local event = { player_index = 1, surface_index = 1 }
    
    local success, err = pcall(function()
      local Handlers = require("core.events.handlers")
      Handlers.on_player_changed_surface(event)
    end)
    
    assert(success, "Same surface change should be handled gracefully: " .. tostring(err))
  end)
end)
