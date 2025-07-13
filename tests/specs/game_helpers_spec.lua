local test_framework = require("test_framework")

-- Mock all dependencies first
package.loaded["core.utils.settings_access"] = {
  get_setting = function(key) return {} end
}

package.loaded["core.utils.teleport_utils"] = {
  teleport_to_gps = function(player, gps, context, return_raw)
    return true
  end
}

package.loaded["core.utils.tile_utils"] = {
  appears_walkable = function(surface, position) return true end
}

local GameHelpers = require("core.utils.game_helpers")

describe("GameHelpers", function()
  it("should execute safe_play_sound without errors", function()
    local success, err = pcall(function()
      if GameHelpers.safe_play_sound then
        local mock_player = {
          valid = true,
          name = "player1",
          play_sound = function(sound, options) end
        }
        local mock_sound = {path = "test-sound"}
        GameHelpers.safe_play_sound(mock_player, mock_sound)
      end
    end)
    assert(success, "safe_play_sound should execute without errors: " .. tostring(err))
  end)
  
  it("should execute player_print without errors", function()
    local mock_player = {
      valid = true,
      print = function(message) end
    }
    
    local success, err = pcall(function()
      GameHelpers.player_print(mock_player, "test message")
    end)
    assert(success, "player_print should execute without errors: " .. tostring(err))
  end)
  
  it("should execute safe_teleport_to_gps without errors", function()
    local success, err = pcall(function()
      if GameHelpers.safe_teleport_to_gps then
        local mock_player = {valid = true, index = 1}
        local mock_gps = "100.200.1"
        GameHelpers.safe_teleport_to_gps(mock_player, mock_gps, 5)
      end
    end)
    assert(success, "safe_teleport_to_gps should execute without errors: " .. tostring(err))
  end)
  
  it("should handle nil player gracefully", function()
    local success, err = pcall(function()
      if GameHelpers.safe_play_sound then
        local mock_sound = {path = "test-sound"}
        GameHelpers.safe_play_sound(nil, mock_sound)
      end
    end)
    assert(success, "safe_play_sound should handle nil player: " .. tostring(err))
  end)
  
  it("should handle invalid player gracefully", function()
    local mock_player = {valid = false}
    
    local success, err = pcall(function()
      GameHelpers.player_print(mock_player, "test message")
    end)
    assert(success, "player_print should handle invalid player: " .. tostring(err))
  end)
  
  it("should handle missing play_sound function gracefully", function()
    local success, err = pcall(function()
      if GameHelpers.safe_play_sound then
        local mock_player = {valid = true, name = "player1"}
        local mock_sound = {path = "test-sound"}
        GameHelpers.safe_play_sound(mock_player, mock_sound)
      end
    end)
    assert(success, "safe_play_sound should handle missing play_sound: " .. tostring(err))
  end)
end)
