-- Require canonical test bootstrap to patch all mocks before any SUT or test code
require("tests.test_bootstrap")


local spy_utils = require("tests.mocks.spy_utils")
local make_spy = spy_utils.make_spy
local PlayerFavoritesMocks = require("tests.mocks.player_favorites_mocks")

local mock_surfaces = {
  [1] = { index = 1, name = "nauvis", valid = true },
  [2] = { index = 2, name = "space", valid = true }
}

_G.script = { on_nth_tick = function() end }
_G.game = {
  players = {},
  get_player = function(player_index) return _G.game.players[player_index] end,
  surfaces = mock_surfaces
}



-- Patch spies BEFORE loading SUT
local Cache = require("core.cache.cache")
make_spy(Cache, "ensure_surface_cache")
make_spy(Cache, "set_player_surface")

-- Now load SUT (handlers) AFTER patching spies
package.loaded["core.events.handlers"] = nil
local Handlers = require("core.events.handlers")


describe("Surface Event Handlers", function()
  before_each(function()
    mock_players = {}
    mock_players[1] = PlayerFavoritesMocks.mock_player(1, "player1", 1)
    _G.game.players[1] = mock_players[1] -- Ensure the handler can find the mock player
    -- Reset spies and reload SUT to ensure spies are attached to the correct instance
    package.loaded["core.cache.cache"].ensure_surface_cache_spy:reset()
    package.loaded["core.cache.cache"].ensure_surface_cache_spy:revert()
    package.loaded["core.cache.cache"].set_player_surface_spy:reset()
    package.loaded["core.cache.cache"].set_player_surface_spy:revert()
    make_spy(package.loaded["core.cache.cache"], "ensure_surface_cache")
    make_spy(package.loaded["core.cache.cache"], "set_player_surface")
    package.loaded["core.events.handlers"] = nil
    Handlers = require("core.events.handlers")
  end)

  after_each(function()
    package.loaded["core.cache.cache"].ensure_surface_cache_spy:reset()
    package.loaded["core.cache.cache"].ensure_surface_cache_spy:revert()
    package.loaded["core.cache.cache"].set_player_surface_spy:reset()
    package.loaded["core.cache.cache"].set_player_surface_spy:revert()
  end)

  it("should call ensure_surface_cache when player changes surface", function()
    local event = { player_index = 1, surface_index = 2 }
    mock_players[1].surface = mock_surfaces[1] -- Start on surface 1, event is for surface 2
    Handlers.on_player_changed_surface(event)
    assert(package.loaded["core.cache.cache"].ensure_surface_cache_spy:was_called(), "ensure_surface_cache should be called")
    local call_args = package.loaded["core.cache.cache"].ensure_surface_cache_spy.calls[1]
    assert(call_args[1] == 2, "ensure_surface_cache should be called with surface index 2")
    assert(package.loaded["core.cache.cache"].set_player_surface_spy:was_called(), "set_player_surface should be called")
    local set_args = package.loaded["core.cache.cache"].set_player_surface_spy.calls[1]
    assert(set_args[1] == mock_players[1], "set_player_surface should be called with correct player")
    assert(set_args[2] == 2, "set_player_surface should be called with surface index 2")
  end)

  it("should handle invalid player gracefully", function()
    local event = { player_index = 999, surface_index = 2 }
    Handlers.on_player_changed_surface(event)
    assert(package.loaded["core.cache.cache"].set_player_surface_spy:call_count() == 0, "set_player_surface should not be called for invalid player")
  end)

  it("should handle player with same surface gracefully", function()
    local event = { player_index = 1, surface_index = 1 }
    Handlers.on_player_changed_surface(event)
    assert(true)
  end)
end)
