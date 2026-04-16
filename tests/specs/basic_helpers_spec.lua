require("test_bootstrap")

local BasicHelpers = require("core.utils.basic_helpers")

describe("BasicHelpers.for_each_player_by_index_asc", function()
  it("invokes callback in ascending player index order", function()
    _G.game = _G.game or {}
    _G.game.players = {}
    _G.game.players[99] = { valid = true, index = 99, name = "p99" }
    _G.game.players[1] = { valid = true, index = 1, name = "p1" }
    _G.game.players[42] = { valid = true, index = 42, name = "p42" }

    local seen = {}
    BasicHelpers.for_each_player_by_index_asc(function(player, player_index)
      table.insert(seen, player_index)
      assert(player.index == player_index, "player.index matches callback index")
    end)

    assert(#seen == 3, "expected three players")
    assert(seen[1] == 1 and seen[2] == 42 and seen[3] == 99, "order must be ascending by index")
  end)

  it("skips invalid players", function()
    _G.game.players = {}
    _G.game.players[2] = { valid = false, index = 2 }
    _G.game.players[3] = { valid = true, index = 3, name = "p3" }

    local seen = {}
    BasicHelpers.for_each_player_by_index_asc(function(_, player_index)
      table.insert(seen, player_index)
    end)

    assert(#seen == 1, "only valid player")
    assert(seen[1] == 3, "only index 3")
  end)
end)

describe("BasicHelpers.for_each_connected_player_by_index_asc", function()
  it("invokes only connected valid players in ascending index order", function()
    _G.game = _G.game or {}
    _G.game.players = {}
    _G.game.players[10] = { valid = true, index = 10, name = "p10", connected = true }
    _G.game.players[2] = { valid = true, index = 2, name = "p2", connected = false }
    _G.game.players[5] = { valid = true, index = 5, name = "p5", connected = true }

    local seen = {}
    BasicHelpers.for_each_connected_player_by_index_asc(function(player, player_index)
      table.insert(seen, player_index)
      assert(player.connected == true)
      assert(player.index == player_index)
    end)

    assert(#seen == 2, "expected two connected players")
    assert(seen[1] == 5 and seen[2] == 10, "order ascending, skips disconnected index 2")
  end)

  it("skips invalid or not connected", function()
    _G.game.players = {}
    _G.game.players[1] = { valid = true, index = 1, connected = false }
    _G.game.players[2] = { valid = false, index = 2, connected = true }

    local seen = {}
    BasicHelpers.for_each_connected_player_by_index_asc(function(_, player_index)
      table.insert(seen, player_index)
    end)

    assert(#seen == 0)
  end)
end)

describe("BasicHelpers.is_space_platform_surface", function()
  it("returns true when surface has a platform", function()
    local surface = { valid = true, platform = { name = "test" } }
    assert(BasicHelpers.is_space_platform_surface(surface) == true)
  end)

  it("returns false when surface has no platform", function()
    local surface = { valid = true, planet = {}, platform = nil }
    assert(BasicHelpers.is_space_platform_surface(surface) == false)
  end)

  it("returns false for nil or invalid surface", function()
    assert(BasicHelpers.is_space_platform_surface(nil) == false)
    assert(BasicHelpers.is_space_platform_surface({ valid = false }) == false)
  end)
end)
