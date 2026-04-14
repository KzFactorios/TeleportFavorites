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
