--[[
game_helpers.lua
TeleportFavorites Factorio Mod
-----------------------------
Game-specific utilities: teleport, sound, space/water detection, tag collision, etc.
Extracted from helpers_suite.lua for better organization and maintainability.
]]

local Constants = require("constants")
local ErrorHandler = require("core.utils.error_handler")
local GPSUtils = require("core.utils.gps_utils")
local SettingsAccess = require("core.utils.settings_access")
local TerrainValidator = require("core.utils.terrain_validator")

---@class GameHelpers
local GameHelpers = {}

function GameHelpers.is_on_space_platform(player)
  if not player or not player.surface or not player.surface.name then return false end
  local name = player.surface.name:lower()
  return name:find("space") ~= nil or name == "space-platform"
end

--- Finds the nearest walkable chart tag to a clicked position within a specified radius
--- @param player LuaPlayer The player whose force and surface will be used
--- @param map_position table The map position to search around {x=number, y=number}
--- @param search_radius Optional explicit search radius (falls back to player settings if nil)
--- @return LuaCustomChartTag|nil The nearest chart tag or nil if none found
function GameHelpers.get_nearest_chart_tag_to_click_position(player, map_position, search_radius)
  if not player then return nil end
  -- Use provided search_radius if available, otherwise fall back to player settings
  local collision_radius = search_radius or SettingsAccess:getPlayerSettings(player).teleport_radius
  if not collision_radius then
    local player_settings = SettingsAccess:getPlayerSettings(player)
    collision_radius = player_settings.teleport_radius or Constants.settings.TELEPORT_RADIUS_DEFAULT
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
      if ct and ct.valid and ct.position and TerrainValidator.is_walkable_position(player.surface, ct.position) then
        local dx = ct.position.x - map_position.x
        local dy = ct.position.y - map_position.y
        local distance = dx * dx + dy * dy -- Square distance is sufficient for comparison

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

--- Check if a position is walkable (can be tagged)
--- Uses comprehensive walkability checks based on Factorio's traversability rules
---@param surface LuaSurface
---@param pos MapPosition
---@return boolean is_walkable
function GameHelpers.is_walkable_position(surface, pos)
  -- Delegate to consolidated terrain validator
  return TerrainValidator.is_walkable_position(surface, pos)
end

function GameHelpers.is_water_tile(surface, pos)
  -- Delegate to consolidated terrain validator
  return TerrainValidator.is_water_tile(surface, pos)
end

function GameHelpers.is_space_tile(surface, pos)
  -- Delegate to consolidated terrain validator
  return TerrainValidator.is_space_tile(surface, pos)
end

local function cya_teleport(player, pos)
  if player and player.valid then
    if pos.x and pos.y then player.teleport({ x = pos.x, y = pos.y }, player.surface) return true end
    if pos[1] and pos[2] then player.teleport({ x = pos[1], y = pos[2] }, player.surface) return true end
  end
  return false
end

function GameHelpers.safe_teleport(player, pos)
  -- do not print msg if player has the setting turned off
  local player_approves_dest_messaging = SettingsAccess:getPlayerSettings(player).destination_msg_on

  if cya_teleport(player, pos) and player_approves_dest_messaging then
    GameHelpers.player_print(player, { "tf-gui.teleported_to", player.name, GPSUtils.coords_string_from_map_position(pos) })
  elseif player_approves_dest_messaging then
    GameHelpers.player_print(player, ("tf-gui.teleport_failed"))
  end
end

function GameHelpers.safe_play_sound(player, sound)
  if player and player.valid and type(player.play_sound) == "function" and type(sound) == "table" then
    local success, err = pcall(function() player.play_sound(sound, {}) end)
    if not success then
      ErrorHandler.debug_log("Failed to play sound", { 
        player = player.name, 
        sound = sound.path or "unknown",
        error = err 
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

-- Tag/favorite state update logic
function GameHelpers.update_favorite_state(player, tag, is_favorite, PlayerFavorites)
  -- PlayerFavorites is required to avoid circular require
  if not PlayerFavorites or not player or not tag then return end
  local pfaves = PlayerFavorites.new(player)
  if is_favorite then
    pfaves:add_favorite(tag.gps)
  else
    pfaves:remove_favorite(tag.gps)
  end
end

function GameHelpers.update_tag_chart_fields(tag, text, icon, player)
  tag.chart_tag = tag.chart_tag or {}
  tag.chart_tag.text = text
  tag.chart_tag.icon = icon
  tag.chart_tag.last_user = (not tag.chart_tag.last_user or tag.chart_tag.last_user == "") and player.name or
      tag.chart_tag.last_user
end

function GameHelpers.update_tag_position(tag, pos, gps)
  tag.chart_tag = tag.chart_tag or {}
  tag.chart_tag.position = pos
  tag.gps = gps
end

return GameHelpers
