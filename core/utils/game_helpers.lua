--[[
game_helpers.lua
TeleportFavorites Factorio Mod
-----------------------------
Game-specific utilities: teleport, sound, space/water detection, tag collision, etc.
Extracted from helpers_suite.lua for better organization and maintainability.
]]

local Constants = require("constants")
local GPSUtils = require("core.utils.gps_utils")
local SettingsAccess = require("core.utils.settings_access")
local TeleportUtils = require("core.utils.teleport_utils")
local TileUtils = require("core.utils.tile_utils")

---@class GameHelpers
local GameHelpers = {}

--- Simple local check if a position appears walkable (not water/space)
--- This is a simplified version to avoid circular dependencies
---@param surface LuaSurface
---@param position MapPosition
---@return boolean appears_walkable
local function appears_walkable(surface, position)
  return TileUtils.appears_walkable(surface, position)
end


--- Finds the nearest walkable chart tag to a clicked position within a specified radius
--- @param player LuaPlayer The player whose force and surface will be used
--- @param map_position table The map position to search around {x=number, y=number}
--- @param search_radius number? Optional explicit search radius (falls back to player settings if nil)
--- @return LuaCustomChartTag|nil The nearest chart tag or nil if none found
function GameHelpers.get_nearest_chart_tag_to_click_position(player, map_position, search_radius)
  if not player then return nil end
  
  -- Use chart tag click radius instead of teleport radius
  local collision_radius = Constants.settings.CHART_TAG_CLICK_RADIUS
  if search_radius and type(search_radius) == "number" then
    collision_radius = search_radius
  end
  
  -- Create collision detection area centered on the map position
  -- Small buffer (0.1) ensures we don't include tags exactly on the boundary
  local collision_area = {
    left_top = { x = map_position.x - collision_radius + 0.1, y = map_position.y - collision_radius + 0.1 },
    right_bottom = { x = map_position.x + collision_radius - 0.1, y = map_position.y + collision_radius - 0.1 }
  }
  local colliding_tags = player.force.find_chart_tags(player.surface, collision_area)
  if colliding_tags and #colliding_tags > 0 then
    local closest_chart_tag = nil
    local min_distance = math.huge
      for _, ct in pairs(colliding_tags) do
      if ct and ct.valid and ct.position and appears_walkable(player.surface, ct.position) then
        local dx = ct.position.x - map_position.x
        local dy = ct.position.y - map_position.y
        -- Square distance is sufficient for comparison
        local distance = dx * dx + dy * dy

        if distance < min_distance then
          min_distance = distance
          closest_chart_tag = ct
        end
      end
    end

    return closest_chart_tag
  end

  return nil
end

local function cya_teleport(player, pos)
  if player and player.valid then
    if pos.x and pos.y then 
      player.teleport({ x = pos.x, y = pos.y }, player.surface) 
      return true 
    end
    if pos[1] and pos[2] then 
      player.teleport({ x = pos[1], y = pos[2] }, player.surface) 
      return true 
    end
  end
  return false
end

function GameHelpers.safe_teleport(player, pos)
  -- Legacy function - convert position to GPS and use strategy-based teleportation
  if not player or not player.valid or not pos then return false end
  
  -- Convert position to GPS format
  local surface_index = player.surface and player.surface.index or 1
  local gps = GPSUtils.gps_from_map_position(pos, surface_index)
  
  -- Use the new strategy-based safe teleportation
  return GameHelpers.safe_teleport_to_gps(player, gps)
end

function GameHelpers.safe_play_sound(player, sound)
  if player and player.valid and type(player.play_sound) == "function" and type(sound) == "table" then
    local success, err = pcall(function() player.play_sound(sound, {}) end)    if not success then
      -- Log directly without using PlayerComm
      pcall(function()
        log("[TeleportFavorites] DEBUG: Failed to play sound for player | player_name=" .. 
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

-- ========================================
-- SHARED TELEPORTATION UTILITIES
-- ========================================

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

--- Teleport with vehicle awareness
---@param player LuaPlayer Player to teleport
---@param gps string GPS coordinates in 'xxx.yyy.s' format
---@param allow_vehicle boolean Whether to allow vehicle teleportation
---@return boolean success Whether teleportation was successful
function GameHelpers.vehicle_aware_teleport_to_gps(player, gps, allow_vehicle)
  local context = {
    allow_vehicle = allow_vehicle
  }
  local result = TeleportUtils.teleport_to_gps(player, gps, context, false)
  if type(result) == "boolean" then
    return result
  else
    return false
  end
end

--- Check if a tile at a position is a water tile
---@param surface LuaSurface Surface to check
---@param position MapPosition Position to check
---@return boolean is_water_tile
function GameHelpers.is_water_tile_at_position(surface, position)
  return TileUtils.is_water_tile_at_position(surface, position)
end

--- Find safe landing position near a potentially unsafe tile (like water)
---@param surface LuaSurface Surface to search on
---@param position MapPosition Original position
---@param search_radius number? Search radius (default: 16.0)
---@param precision number? Search precision (default: 0.5)
---@return MapPosition? safe_position Safe position or nil if none found
function GameHelpers.find_safe_landing_position(surface, position, search_radius, precision)
  return TileUtils.find_safe_landing_position(surface, position, search_radius, precision)
end

return GameHelpers
