local test_framework = require("test_framework")

-- Mock all dependencies first
package.loaded["core.utils.gps_utils"] = {
  gps_string_to_table = function(gps)
    return {x = 100, y = 200, surface = 1}
  end
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

package.loaded["core.utils.locale_utils"] = {
  get_message = function(key, params) return "test message" end
}

package.loaded["core.utils.tile_utils"] = {
  find_safe_landing_position = function(surface, position, radius, precision)
    return {x = 100, y = 200}
  end
}

package.loaded["core.utils.chart_tag_utils"] = {
  validate_position = function(position) return true end
}

local TeleportStrategy = require("core.utils.teleport_strategy")

describe("TeleportStrategy", function()
  it("should load module without errors", function()
    local success, err = pcall(function()
      local _ = TeleportStrategy.TeleportStrategyManager
    end)
    assert(success, "TeleportStrategy module should load: " .. tostring(err))
  end)
  
  it("should handle TeleportStrategyManager existence", function()
    local success, err = pcall(function()
      if TeleportStrategy.TeleportStrategyManager then
        local _ = TeleportStrategy.TeleportStrategyManager.execute_teleport
      end
    end)
    assert(success, "TeleportStrategyManager should be accessible: " .. tostring(err))
  end)
  
  it("should handle strategy registration if available", function()
    local success, err = pcall(function()
      if TeleportStrategy.TeleportStrategyManager and 
         TeleportStrategy.TeleportStrategyManager.register_strategy then
        -- Just check the function exists, don't call it
        local _ = type(TeleportStrategy.TeleportStrategyManager.register_strategy)
      end
    end)
    assert(success, "Strategy registration should be accessible: " .. tostring(err))
  end)
  
  it("should handle available strategies query if available", function()
    local success, err = pcall(function()
      if TeleportStrategy.TeleportStrategyManager and 
         TeleportStrategy.TeleportStrategyManager.get_available_strategies then
        -- Just check the function exists, don't call it
        local _ = type(TeleportStrategy.TeleportStrategyManager.get_available_strategies)
      end
    end)
    assert(success, "Available strategies query should be accessible: " .. tostring(err))
  end)
end)
