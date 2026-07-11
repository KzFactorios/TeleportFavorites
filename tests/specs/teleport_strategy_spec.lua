require("test_bootstrap")

-- Use real GPS parsing for teleport strategy tests (bootstrap stubs fixed coords).
package.loaded["core.utils.gps_utils"] = nil
require("core.utils.gps_utils")

package.loaded["core.utils.chart_tag_utils"] = {
  find_closest_chart_tag_to_position = function() return nil end,
}

local Cache = require("core.cache.cache")
Cache.Lookups = Cache.Lookups or {}
Cache.Lookups.get_chart_tag_by_gps = function() return nil end

package.loaded["core.utils.teleport_strategy"] = nil
local TeleportStrategy = require("core.utils.teleport_strategy")

local function make_target_surface()
  return {
    valid = true,
    index = 1,
    find_non_colliding_position = function(_name, center, _radius, _precision)
      return { x = center.x, y = center.y }
    end,
  }
end

describe("TeleportStrategy.teleport_to_gps remote view", function()
  it("teleports character (not player camera) when camera matches target but character does not", function()
    _G.defines.controllers = _G.defines.controllers or {}
    _G.defines.controllers.remote = "remote"

    local target_surface = make_target_surface()
    _G.game.get_surface = function(idx)
      if math.floor(tonumber(idx) or 0) == 1 then return target_surface end
      return nil
    end

    local character_teleported = false
    local player_teleported = false
    local exited_remote = false
    local character = {
      valid = true,
      position = { x = 10, y = 10 },
      surface = target_surface,
      teleport = function()
        character_teleported = true
        return true
      end,
    }
    local player = {
      valid = true,
      name = "test",
      index = 1,
      position = { x = 50, y = 50 },
      surface = target_surface,
      physical_position = { x = 10, y = 10 },
      physical_surface_index = 1,
      character = character,
      controller_type = "remote",
      exit_remote_view = function() exited_remote = true end,
      teleport = function()
        player_teleported = true
        return true
      end,
    }

    local ok, result = TeleportStrategy.teleport_to_gps(player, "050.050.1", false)
    assert(ok == true, "expected teleport success, got: " .. tostring(result))
    assert(character_teleported == true, "character.teleport should run in remote view")
    assert(player_teleported == false, "player.teleport must not run when character exists on same surface")
    assert(exited_remote == true, "should exit remote view after success")
  end)

  it("short-circuits already_at_target using physical position in remote view", function()
    local target_surface = make_target_surface()
    _G.game.get_surface = function(idx)
      if math.floor(tonumber(idx) or 0) == 1 then return target_surface end
      return nil
    end

    local character_teleported = false
    local character = {
      valid = true,
      position = { x = 50, y = 50 },
      surface = target_surface,
      teleport = function()
        character_teleported = true
        return true
      end,
    }
    local player = {
      valid = true,
      name = "test",
      index = 1,
      position = { x = 99, y = 99 },
      surface = target_surface,
      physical_position = { x = 50, y = 50 },
      physical_surface_index = 1,
      character = character,
      teleport = function()
        character_teleported = true
        return true
      end,
    }

    local ok, result = TeleportStrategy.teleport_to_gps(player, "050.050.1", false)
    assert(ok == false, "expected failure")
    assert(result == "already_at_target", "expected already_at_target, got: " .. tostring(result))
    assert(character_teleported == false, "should not teleport when already at target")
  end)

  it("treats equivalent padded GPS strings as already_at_target", function()
    local target_surface = make_target_surface()
    _G.game.get_surface = function(idx)
      if math.floor(tonumber(idx) or 0) == 1 then return target_surface end
      return nil
    end

    local character_teleported = false
    local character = {
      valid = true,
      position = { x = 50, y = 50 },
      surface = target_surface,
      teleport = function()
        character_teleported = true
        return true
      end,
    }
    local player = {
      valid = true,
      name = "test",
      index = 1,
      position = { x = 99, y = 99 },
      surface = target_surface,
      physical_position = { x = 50, y = 50 },
      physical_surface_index = 1,
      character = character,
    }

    -- player_gps normalizes to padded form; target uses unpadded x/y with same values
    local ok, result = TeleportStrategy.teleport_to_gps(player, "50.50.1", false)
    assert(ok == false, "expected failure")
    assert(result == "already_at_target", "expected already_at_target, got: " .. tostring(result))
    assert(character_teleported == false, "normalized GPS compare should short-circuit")
  end)
end)
