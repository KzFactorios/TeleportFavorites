---@diagnostic disable: undefined-global

local ErrorHandler = require("core.utils.error_handler")

---@class GameHelpers
local GameHelpers = {}

function GameHelpers.safe_play_sound(player, sound)
  if player and player.valid and type(player.play_sound) == "function" and type(sound) == "table" then
    local success, err = pcall(function() player.play_sound(sound, {}) end)if not success then
      pcall(function()
        ErrorHandler.debug_log("[TeleportFavorites] DEBUG: Failed to play sound for player | player_name=" ..
          (player.name or "unknown") .. " sound_path=" .. (sound.path or "unknown") ..
          " error_message=" .. tostring(err))
      end)
    end
  end
end

function GameHelpers.player_print(player, message)
  if player and player.valid and type(player.print) == "function" then
    pcall(function() player.print(message) end)
  end
end

return GameHelpers
