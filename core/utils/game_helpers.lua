

-- core/utils/game_helpers.lua
-- TeleportFavorites Factorio Mod
-- Game-specific utilities for teleportation, sound playback, space/water detection, tag collision, and player messaging.
-- Integrates with ErrorHandler and TeleportStrategies for robust multiplayer-safe operations.

local ErrorHandler = require("core.utils.error_handler")

---@class GameHelpers
local GameHelpers = {}

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

return GameHelpers
