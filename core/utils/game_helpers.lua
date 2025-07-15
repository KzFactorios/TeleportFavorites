--[[
game_helpers.lua
TeleportFavorites Factorio Mod
-----------------------------
Game-specific utilities: teleport, sound, space/water detection, tag collision, etc.
Extracted from helpers_suite.lua for better organization and maintainability.
]]

local ErrorHandler = require("core.utils.error_handler")
local SettingsCache = require("core.cache.settings_cache")
local TeleportStrategies = require("core.utils.teleport_strategy")
local TeleportUtils = TeleportStrategies.TeleportUtils
local PositionUtils = require("core.utils.position_utils")

---@class GameHelpers
local GameHelpers = {}

--- Simple local check if a position appears walkable (not water/space)
--- This is a simplified version to avoid circular dependencies
---@param surface LuaSurface
---@param position MapPosition
---@return boolean appears_walkable
local function appears_walkable(surface, position)
  return PositionUtils.appears_walkable(surface, position)
end

function GameHelpers.safe_play_sound(player, sound)
  if player and player.valid and type(player.play_sound) == "function" and type(sound) == "table" then
    local success, err = pcall(function() player.play_sound(sound, {}) end)if not success then
      -- Log directly without using PlayerComm
      pcall(function()
        ErrorHandler.debug_log("[TeleportFavorites] DEBUG: Failed to play sound for player | player_name=" .. 
          (player.name or "unknown") .. " sound_path=" .. (sound.path or "unknown") .. 
          " error_message=" .. tostring(err))
      end)
    end
  end
end

-- Player print
function GameHelpers.player_print(player, message)
  if player and player.valid and type(player.print) == "function" then
    pcall(function() player.print(message) end)
  end
end

--- Safe teleport with water tile detection and landing position finding
---@param player LuaPlayer Player to teleport
---@param gps string GPS coordinates in 'xxx.yyy.s' format
---@param custom_radius number? Custom safety radius for finding safe positions
---@return boolean success Whether teleportation was successful
function GameHelpers.safe_teleport_to_gps(player, gps, custom_radius)
  local context = {
    force_safe = true,
    custom_radius = custom_radius
  }
  local result = TeleportUtils.teleport_to_gps(player, gps, context, false)
  if type(result) == "boolean" then
    return result
  else
    return false
  end
end

return GameHelpers
