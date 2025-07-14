-- tests/mocks/test_helpers.lua  
-- Safe helper functions for test patterns that don't affect production code

local MockFactories = require("mocks.mock_factories")

---@class TestHelpers
local TestHelpers = {}

--- Create a basic mock player for testing (commonly used pattern)
---@param index number? Player index (default: 1)
---@param name string? Player name (default: "TestPlayer")
---@return table mock_player
function TestHelpers.mock_player(index, name)
  return MockFactories.create_player({
    index = index or 1,
    name = name or "TestPlayer",
    valid = true,
    admin = false
  })
end

--- Create a mock element for GUI testing (commonly used pattern)
---@param name string? Element name (default: "test_element")  
---@param valid boolean? Whether element is valid (default: true)
---@return table mock_element
function TestHelpers.mock_element(name, valid)
  return MockFactories.create_element({
    name = name or "test_element",
    valid = valid ~= false
  })
end

--- Create mock game object for testing
---@param players table? Players table (default: empty)
---@return table mock_game
function TestHelpers.mock_game(players)
  players = players or {}
  return {
    get_player = function(index) 
      return players[index] or TestHelpers.mock_player(index)
    end,
    players = players,
    print = function() end
  }
end

--- Safe wrapper for pcall tests that expect success
---@param func function Function to test
---@param error_msg string? Custom error message
---@return boolean success Always returns true for assertions
function TestHelpers.should_not_error(func, error_msg)
  local success, err = pcall(func)
  if not success then
    error((error_msg or "Function should not error") .. ": " .. tostring(err))
  end
  return true
end

--- Create mock game with multiple players
---@param player_configs table Array of player configurations
---@return table mock_game
function TestHelpers.create_mock_game_with_players(player_configs)
  local players = {}
  local connected_players = {}
  
  for _, config in ipairs(player_configs) do
    local player = MockFactories.create_player(config)
    players[player.index] = player
    if player.connected then
      connected_players[player.index] = player
    end
  end
  
  _G.game = {
    tick = 1000,
    players = players,
    connected_players = connected_players,
    get_player = function(index) 
      return players[index] 
    end
  }
  
  return _G.game
end

return TestHelpers
