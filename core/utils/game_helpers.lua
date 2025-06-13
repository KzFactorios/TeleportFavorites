--[[
game_helpers.lua
TeleportFavorites Factorio Mod
-----------------------------
Game-specific utilities: teleport, sound, space/water detection, tag collision, etc.
Extracted from helpers_suite.lua for better organization and maintainability.
]]

local Constants = require("constants")
local gps_core = require("core.utils.gps_core")
local SettingsAccess = require("core.utils.settings_access")

---@class GameHelpers
local GameHelpers = {}

function GameHelpers.is_on_space_platform(player)
  if not player or not player.surface or not player.surface.name then return false end
  local name = player.surface.name:lower()
  return name:find("space") ~= nil or name == "space-platform"
end

--- Finds the nearest chart tag to a clicked position within a specified radius
-- @param player LuaPlayer The player whose force and surface will be used
-- @param map_position table The map position to search around {x=number, y=number}
-- @param search_radius Optional explicit search radius (falls back to player settings if nil)
-- @return The nearest chart tag or nil if none found
function GameHelpers.get_nearest_tag_to_click_position(player, map_position, search_radius)
  if not player then return nil end
  -- Use provided search_radius if available, otherwise fall back to player settings
  local collision_radius = search_radius
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
    -- If only one tag found, just return it
    if #colliding_tags == 1 then
      return colliding_tags[1]
    end

    -- If multiple tags found, find the closest one to map_position
    local closest_tag = nil
    local min_distance = math.huge

    for _, tag in pairs(colliding_tags) do
      if tag and tag.valid and tag.position then
        local dx = tag.position.x - map_position.x
        local dy = tag.position.y - map_position.y
        local distance = dx * dx + dy * dy -- Square distance is sufficient for comparison

        if distance < min_distance then
          min_distance = distance
          closest_tag = tag
        end
      end
    end

    return closest_tag
  end

  return nil
end

function GameHelpers.is_water_tile(surface, pos)
  if not surface or not surface.get_tile then return false end
  
  local x, y = math.floor(pos.x), math.floor(pos.y)
  local tile = surface.get_tile(x, y)
  if not tile then return false end
  
  -- Primary method: Use collides_with which is the most reliable for modern Factorio
  local collides_water = tile.collides_with("water-tile")
  if collides_water then
    return true
  end
  
  -- Fallback method: Check tile name for common water patterns
  local tile_name = tile.name
  if tile_name then
    local name = tile_name:lower()
    -- Check for various water tile naming patterns
    if name:find("water") or name:find("deepwater") or name:find("shallow%-water") or 
       name == "water" or name == "deepwater" or name == "shallow-water" then
      return true
    end
  end
  
  return false
end

function GameHelpers.is_space_tile(surface, pos)
  if not surface or not surface.get_tile then return false end
  local tile = surface.get_tile(math.floor(pos.x), math.floor(pos.y))
  if not tile then return false end
  
  -- Primary method: Use collides_with for space platforms
  if tile.collides_with("space-tile") then
    return true
  end
  
  -- Fallback method: Check tile name for space patterns  
  if tile.name then
    local name = tile.name:lower()
    -- Common space tile names in Factorio
    if name:find("space") or name:find("void") or name == "out-of-map" then
      return true
    end
  end
  
  return false
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
    GameHelpers.player_print(player, { "tf-gui.teleported_to", player.name, gps_core.coords_string_from_map_position(pos) })
  elseif player_approves_dest_messaging then
    GameHelpers.player_print(player, ("tf-gui.teleport_failed"))
  end
end

function GameHelpers.safe_play_sound(player, sound)
  if player and player.valid and type(player.play_sound) == "function" and type(sound) == "table" then
    pcall(function() player.play_sound(sound, {}) end)
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
