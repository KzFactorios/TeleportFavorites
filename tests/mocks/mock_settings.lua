-- tests/mocks/mock_settings.lua
-- Minimal mock for global settings table used by cache

local mock_settings = {}

function mock_settings.get_player_settings(player)
  return {
    ["show-player-coords"] = { value = true }
  }
end

return mock_settings
