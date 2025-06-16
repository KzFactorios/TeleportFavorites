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
local ErrorHandler = require("core.utils.error_handler")

---@class GameHelpers
local GameHelpers = {}

--- Simple local check if a position appears walkable (not water/space)
--- This is a simplified version to avoid circular dependencies
---@param surface LuaSurface
---@param position MapPosition
---@return boolean appears_walkable
local function appears_walkable(surface, position)
  if not surface or not surface.get_tile or not position then return false end
  
  local tile = surface:get_tile(position.x, position.y)
  if not tile or not tile.valid then return false end
  
  local tile_name = tile.name:lower()
  -- Simple check for obviously non-walkable tiles
  if tile_name:find("water") or tile_name:find("space") or tile_name:find("void") then
    return false
  end
  
  return true
end


--- Finds the nearest walkable chart tag to a clicked position within a specified radius
--- @param player LuaPlayer The player whose force and surface will be used
--- @param map_position table The map position to search around {x=number, y=number}
--- @param search_radius number? Optional explicit search radius (falls back to player settings if nil)
--- @return LuaCustomChartTag|nil The nearest chart tag or nil if none found
function GameHelpers.get_nearest_chart_tag_to_click_position(player, map_position, search_radius)
  if not player then return nil end
  
  -- Ensure collision_radius is always a number
  local collision_radius = Constants.settings.TELEPORT_RADIUS_DEFAULT
  if search_radius and type(search_radius) == "number" then
    collision_radius = search_radius
  else
    local player_settings = SettingsAccess:getPlayerSettings(player)
    local radius_value = player_settings.teleport_radius
    if type(radius_value) == "number" then
      collision_radius = radius_value
    end
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
  -- Do not print msg if player has the setting turned off
  local player_settings = SettingsAccess:getPlayerSettings(player)
  -- Default to true for safety
  local player_approves_dest_messaging = player_settings and type(player_settings.destination_msg_on) == "boolean" and player_settings.destination_msg_on or true
  
  local teleport_success = cya_teleport(player, pos)

  if teleport_success and player_approves_dest_messaging then
    GameHelpers.player_print(player, { "tf-gui.teleported_to", player.name, GPSUtils.coords_string_from_map_position(pos) })
  elseif not teleport_success and player_approves_dest_messaging then
    GameHelpers.player_print(player, "tf-gui.teleport_failed")
  end
end

function GameHelpers.safe_play_sound(player, sound)
  if player and player.valid and type(player.play_sound) == "function" and type(sound) == "table" then
    local success, err = pcall(function() player.play_sound(sound, {}) end)
    if not success then
      -- Use ErrorHandler for consistent logging
      ErrorHandler.debug_log("Failed to play sound for player", {
        player_name = player.name or "unknown",
        sound_path = sound.path or "unknown",
        error_message = err
      })
    end
  end
end

-- Player print (already present, but ensure DRY)
function GameHelpers.player_print(player, message)
  if player and player.valid and type(player.print) == "function" then
    player.print(message)
  end
end

return GameHelpers
