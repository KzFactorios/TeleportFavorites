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

---@class Positionhelpers
local Positionhelpers = {}

--- Returns true if a tag can be placed at the given map position for the player
---@param player LuaPlayer
---@param map_position table
---@return boolean
function Positionhelpers.position_can_be_tagged(player, map_position)
  if not (player and player.force and player.surface and player.force.is_chunk_charted) then return false end
  local chunk = { x = math.floor(map_position.x / 32), y = math.floor(map_position.y / 32) }
  if not player.force:is_chunk_charted(player.surface, chunk) then
    player:print("[TeleportFavorites] You are trying to create a tag in uncharted territory: " ..
    gps_helpers.gps_from_map_position(map_position, player.surface.index))
    return false
  end
  if Helpers.is_water_tile(player.surface, map_position) or Helpers.is_space_tile(player.surface, map_position) then
    player:print("[TeleportFavorites] You cannot tag water or space in this interface: " ..
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
  if not player then return end
  local pos = player.position or { x = 0, y = 0 }
  if type(player.print) == "function" then
    local gps_string = gps_helpers.gps_from_map_position(pos, player.surface.index)
    player:print({ "teleported-to", player.name, gps_string })
  end
end

return Positionhelpers
