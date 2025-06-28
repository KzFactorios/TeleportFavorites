---@diagnostic disable: undefined-global
--[[
core/events/player_state_helpers.lua
TeleportFavorites Factorio Mod
-----------------------------
Helper functions for player state management, extracted from handlers.lua.

This module contains functions for:
- Player state initialization and cleanup
- Transient state reset on player joins/reconnections
- Multiplayer state synchronization

These functions were extracted from large event handlers to improve
maintainability and support for multiplayer scenarios.
]]

local Cache = require("core.cache.cache")

---@class PlayerStateHelpers
local PlayerStateHelpers = {}

--- Ensures clean state regardless of how player previously left the game (moved from handlers.lua)
---@param player LuaPlayer
function PlayerStateHelpers.reset_transient_player_states(player)
  if not player or not player.valid then return end
  
  local player_data = Cache.get_player_data(player)
  
  -- Reset drag mode state
  if player_data.drag_favorite then
    player_data.drag_favorite.active = false
    player_data.drag_favorite.source_slot = nil
    player_data.drag_favorite.favorite = nil
  end
  
  -- Reset move mode state in tag editor
  if player_data.tag_editor_data then
    if player_data.tag_editor_data.move_mode then
      player_data.tag_editor_data.move_mode = false
    end
    -- Clear any error messages from previous session
    player_data.tag_editor_data.error_message = ""
  end
end

return PlayerStateHelpers
