local test_framework = require("tests.test_framework")

-- Mock all dependencies first
package.loaded["core.utils.game_helpers"] = {
  player_print = function(player, message) end
}

package.loaded["core.cache.cache"] = {
  get_player_teleport_history = function(player, surface_index)
    return {
      stack = {{x = 100, y = 200, surface = 1}},
      pointer = 1
    }
  end
}

package.loaded["core.utils.gps_utils"] = {
  table_to_gps_string = function(position)
    return "100.200.1"
  end,
  gps_string_to_table = function(gps)
    return {x = 100, y = 200, surface = 1}
  end
}

local TeleportHistory = require("core.teleport.teleport_history")

describe("TeleportHistory", function()
  it("should execute add_gps without errors", function()
    local mock_player = {valid = true, index = 1}
    local mock_gps = {x = 150, y = 250, surface = 1}
    
    local success, err = pcall(function()
      TeleportHistory.add_gps(mock_player, mock_gps)
    end)
    assert(success, "add_gps should execute without errors: " .. tostring(err))
  end)
  
  it("should execute move_pointer without errors", function()
    local mock_player = {
      valid = true, 
      index = 1,
      surface = {index = 1}
    }
    
    local success, err = pcall(function()
      TeleportHistory.move_pointer(mock_player, "up", false)
    end)
    assert(success, "move_pointer should execute without errors: " .. tostring(err))
  end)
  
  it("should handle nil player in add_gps gracefully", function()
    local mock_gps = {x = 150, y = 250, surface = 1}
    
    local success, err = pcall(function()
      TeleportHistory.add_gps(nil, mock_gps)
    end)
    assert(success, "add_gps should handle nil player: " .. tostring(err))
  end)
  
  it("should handle nil player in move_pointer gracefully", function()
    local success, err = pcall(function()
      TeleportHistory.move_pointer(nil, "up", false)
    end)
    assert(success, "move_pointer should handle nil player: " .. tostring(err))
  end)
  
  it("should handle invalid gps in add_gps gracefully", function()
    local mock_player = {valid = true, index = 1}
    
    local success, err = pcall(function()
      TeleportHistory.add_gps(mock_player, nil)
    end)
    assert(success, "add_gps should handle nil gps: " .. tostring(err))
  end)
end)
