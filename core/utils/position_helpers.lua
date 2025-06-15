--[[
position_helpers.lua
TeleportFavorites Factorio Mod
-----------------------------
Utility functions for position, map, and tag helpers that require game logic or GPS module.
Separated from helpers.lua to avoid circular dependencies.

- Tag placement validation: checks if a tag can be placed at a given map position for a player (charted, not water).
- Teleport event messaging: prints a localized message to the player after teleporting.

All helpers are static and namespaced under Positionhelpers.
]]

local Helpers = require("core.utils.helpers_suite")
local gps_helpers = require("core.utils.gps_helpers")
local GameHelpers = require("core.utils.game_helpers")
local ValidationHelpers = require("core.utils.validation_helpers")

---@class Positionhelpers
local Positionhelpers = {}

--- Returns true if a tag can be placed at the given map position for the player
---@param player LuaPlayer
---@param map_position table
---@return boolean
function Positionhelpers.position_can_be_tagged(player, map_position)
  -- Use consolidated validation helper for player and position checks
  local valid, position, error_msg = ValidationHelpers.validate_position_operation(player, 
    gps_helpers.gps_from_map_position(map_position, player and player.surface and player.surface.index or 1))
  
  if not valid then
    if player and player.valid then
      GameHelpers.player_print(player, "[TeleportFavorites] " .. (error_msg or "Cannot tag this location"))
    end
    return false
  end
  
  -- Check if position is walkable (consolidated water/space check)
  if not Helpers.is_walkable_position(player.surface, map_position) then
    GameHelpers.player_print(player, "[TeleportFavorites] You cannot tag water or space in this interface: " ..
      gps_helpers.gps_from_map_position(map_position, player.surface.index))
    return false
  end
  
  return true
end

--- Print a localized message to the player after teleporting
---@param event table
---@param game table
function Positionhelpers.on_raise_teleported(event, game)
  if not (event and event.player_index and game and type(game.get_player) == "function") then return end
  
  local player = game.get_player(event.player_index)
  if not player or not player.valid then return end
  
  local pos = player.position or { x = 0, y = 0 }
  if type(player.print) == "function" then
    local gps_string = gps_helpers.gps_from_map_position(pos, player.surface.index)
    GameHelpers.player_print(player, { "teleported-to", player.name, gps_string })
  end
end

return Positionhelpers
