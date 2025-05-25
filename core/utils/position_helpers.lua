-- PositionHelpers.lua
-- Utility functions for position, map, and tag helpers that require game logic or GPS module.
-- This module is separated from Helpers.lua to avoid circular dependencies.

local GPS = require("core.gps.gps")

---@class PositionHelpers
local PositionHelpers = {}

--- Returns true if a tag can be placed at the given map position for the player
---@param player LuaPlayer
---@param map_position table
---@return boolean
function PositionHelpers.position_can_be_tagged(player, map_position)
  if not player then return false end
  local chunk_position = {
    x = math.floor(map_position.x / 32),
    y = math.floor(map_position.y / 32)
  }
  if not (player.force and player.surface and player.force.is_chunk_charted) then
    return false
  end
  if not player.force:is_chunk_charted(player.surface, chunk_position) then
    player:print("[TeleportFavorites] You are trying to create a tag in uncharted territory: " .. GPS.map_position_to_gps(map_position))
    return false
  end
  local tile = player.surface.get_tile(player.surface, math.floor(map_position.x), math.floor(map_position.y))
  for _, mask in pairs(tile.prototype.collision_mask) do
    if mask == "water-tile" then
      return false
    end
  end
  return true
end

--- Print a localized message to the player after teleporting
---@param event table
---@param game table
function PositionHelpers.on_raise_teleported(event, game)
  if not event or not event.player_index then return end
  if not game or type(game.get_player) ~= "function" then return end
  local player = game.get_player(event.player_index)
  if not player then return end
  local pos = player.position or { x = 0, y = 0 }
  if type(player.print) == "function" then
    -- do not add the [TeleportFavorites] at the head of the output to reduce clutter
    local gps_string = GPS.coords_string_from_gps(GPS.gps_from_map_position(pos, player.surface.index))
    ---@diagnostic disable-next-line
    player:print({ "teleported-to", player.name, gps_string })
  end
  --Slots.update_slots(player)
end

return PositionHelpers
