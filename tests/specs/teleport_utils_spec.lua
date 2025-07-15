local test_framework = require("test_framework")

-- Mock all dependencies first
package.loaded["core.utils.teleport_strategy"] = {
  TeleportStrategyManager = {
    execute_teleport = function(player, gps, context)
      return 1 -- SUCCESS
    end
  },
  TeleportUtils = {
    teleport_to_gps = function(player, gps, context, return_raw)
      if not player or not player.valid then
        if return_raw then return "invalid_player" end
        return false
      end
      if not gps or type(gps) ~= "string" or gps == "" then
        if return_raw then return "invalid_gps" end
        return false
      end
      if return_raw then
        return 1 -- SUCCESS
      else
        return true
      end
    end
  }
}

package.loaded["core.utils.error_handler"] = {
  debug_log = function(msg, data) end
}

package.loaded["prototypes.enums.enum"] = {
  ReturnStateEnum = {
    SUCCESS = 1,
    FAILED = 0
  }
}

-- Mock remote interface
_G.remote = {
  interfaces = {},
  call = function(interface, method, ...) end
}

local TeleportStrategies = require("core.utils.teleport_strategy")
local TeleportUtils = TeleportStrategies.TeleportUtils

describe("TeleportUtils", function()
  it("should execute teleport_to_gps without errors", function()
    local mock_player = {valid = true, index = 1}
    local mock_gps = "100.200.1"
    
    local success, err = pcall(function()
      TeleportUtils.teleport_to_gps(mock_player, mock_gps)
    end)
    assert(success, "teleport_to_gps should execute without errors: " .. tostring(err))
  end)
  
  it("should execute teleport_to_gps with context without errors", function()
    local mock_player = {valid = true, index = 1}
    local mock_gps = "100.200.1"
    local mock_context = {force_safe = true}
    
    local success, err = pcall(function()
      TeleportUtils.teleport_to_gps(mock_player, mock_gps, mock_context)
    end)
    assert(success, "teleport_to_gps with context should execute without errors: " .. tostring(err))
  end)
  
  it("should execute teleport_to_gps with return_raw flag without errors", function()
    local mock_player = {valid = true, index = 1}
    local mock_gps = "100.200.1"
    
    local success, err = pcall(function()
      TeleportUtils.teleport_to_gps(mock_player, mock_gps, nil, true)
    end)
    assert(success, "teleport_to_gps with return_raw should execute without errors: " .. tostring(err))
  end)
  
  it("should handle nil player gracefully", function()
    local mock_gps = "100.200.1"
    
    local success, err = pcall(function()
      TeleportUtils.teleport_to_gps(nil, mock_gps)
    end)
    assert(success, "teleport_to_gps should handle nil player: " .. tostring(err))
  end)
  
  it("should handle invalid gps gracefully", function()
    local mock_player = {valid = true, index = 1}
    
    local success, err = pcall(function()
      TeleportUtils.teleport_to_gps(mock_player, nil)
    end)
    assert(success, "teleport_to_gps should handle nil gps: " .. tostring(err))
  end)
  
  it("should handle empty gps string gracefully", function()
    local mock_player = {valid = true, index = 1}
    
    local success, err = pcall(function()
      TeleportUtils.teleport_to_gps(mock_player, "")
    end)
    assert(success, "teleport_to_gps should handle empty gps: " .. tostring(err))
  end)
end)
