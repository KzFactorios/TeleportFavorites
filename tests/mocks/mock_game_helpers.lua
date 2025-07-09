-- tests/mock_game_helpers.lua
-- Minimal mock for core.utils.game_helpers to allow ErrorHandler and other modules to run

local GameHelpers = {}
function GameHelpers.player_print(player, msg)
  -- Simulate printing to player
  if _G._test_player_print then
    _G._test_player_print(player, msg)
    return
  end
  if player and player.valid and type(player.print) == "function" then
    player:print(msg)
  end
end
return GameHelpers
