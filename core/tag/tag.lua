local Constants = require("constants")
local Settings = require("settings")
local Helpers = require("core.utils.Helpers")

---@class Tag
---@field gps string # The GPS string (serves as the index)
---@field chart_tag LuaCustomChartTag # Cached chart tag (private, but no underscore)
---@field faved_by_players uint[] # Array of player indices who have favorited this tag

local Tag = {}
Tag.__index = Tag

--- Constructor for Tag
---@param gps string
---@param faved_by_players uint[]|nil
function Tag:new(gps, faved_by_players)
  assert(type(gps) == "string", "gps must be a string")
  local obj = setmetatable({}, self)
  obj.gps = gps
  obj.chart_tag = nil
  obj.faved_by_players = faved_by_players or {}
  return obj
end

--- Get the related LuaCustomChartTag, retrieving and caching it by gps
---@return LuaCustomChartTag|nil
function Tag:get_chart_tag()
  if not self.chart_tag then
    self.chart_tag = Tag.get_chart_tag_by_gps(self.gps)
  end
  return self.chart_tag
end

--- Static method to fetch a LuaCustomChartTag by gps (implement lookup logic as needed)
---@param gps string
---@return LuaCustomChartTag|nil
function Tag.get_chart_tag_by_gps(gps)
  -- TODO: Implement actual lookup logic using your runtime cache or helpers
  
  
  return nil
end

function Tag:is_player_favorite(player)
  if not self or not self.faved_by_players then return false end
  for _, idx in ipairs(self.faved_by_players) do
    if idx == player.index then return true end
  end
  return false
end

--- Add a player index to faved_by_players (if not already present)
---@param player_index uint
function Tag:add_faved_by_player(player_index)
  assert(type(player_index) == "number", "player_index must be a number")
  for _, idx in ipairs(self.faved_by_players) do
    if idx == player_index then return end
  end
  table.insert(self.faved_by_players, player_index)
end

--- Remove a player index from faved_by_players
---@param player_index uint
function Tag:remove_faved_by_player(player_index)
  for i, idx in ipairs(self.faved_by_players) do
    if idx == player_index then
      table.remove(self.faved_by_players, i)
      return
    end
  end
end

---
--- Teleports a player to a given position on a surface, with robust checks and messaging.
--- Handles vehicle teleportation, collision, water, and space platform restrictions.
--- Returns a localized error string on failure, or Constants.enums.return_state.SUCCESS on success.
---
--- @param player LuaPlayer The player to teleport
--- @param position MapPosition The target position to teleport to
--- @param surface LuaSurface|nil The surface to teleport to (defaults to player's surface)
--- @param raise_teleported boolean|nil If true, raises the on_player_teleported event
--- @return string|integer Localized error string on failure, or Constants.enums.return_state.SUCCESS on success
function Tag.teleport_player_with_messaging(player, position, surface, raise_teleported)
  -- Defensive checks for valid player and surface
  if not player or not player.valid or type(player.teleport) ~= "function" then
    return "Unable to teleport. Player is missing"
  end
  if not surface then surface = player.surface end
  if not surface or type(surface.find_non_colliding_position) ~= "function" then
    return "Unable to teleport. Surface is missing"
  end
  -- Only allow teleport if player.character is present (Factorio API)
  if rawget(player, "character") == nil then
    return "Unable to teleport. Player character is missing"
  end

  -- Space platform check
  if Helpers.is_on_space_platform and Helpers.is_on_space_platform(player) then
    return
    "The insurance general has determined that teleporting on a space platform could result in injury or death, or both, and has outlawed the practice."
  end

  -- Get settings
  local settings = Settings.getPlayerSettings and Settings:getPlayerSettings(player) or { teleport_radius = 8 }
  local teleport_radius = settings.teleport_radius or 8

  -- Use the default prototype name for collision search
  local proto_name = "character"
  -- Find a non-colliding position near the target position
  -- fun(self: LuaSurface, name: string, center: MapPosition, radius: double, precision: double): MapPosition?
  local closest_position = 
    surface:find_non_colliding_position(proto_name, position, teleport_radius, 4)
  if not closest_position then
    return
    "The location you have chosen is too dense for teleportation. You may try to adjust the settings for teleport radius, but generally you should try a different location."
  end

  -- Water tile check
  if Helpers.is_water_tile(surface, closest_position) then
    return
    "You cannot teleport onto water. Ages ago, this practice was allowed and many agents were lost as they were teleported to insurvivable depths. Please select a land location."
  end
  -- Check if the position is valid for placing the player
  if not surface.can_place_entity or not surface:can_place_entity(closest_position) then
    return "The player cannot be placed at this location. Try another location."
  end

  local teleport_AOK = false

  -- Vehicle teleportation: In Factorio, teleporting a vehicle does NOT move the player with it automatically.
  -- To ensure the player stays inside the vehicle, you must teleport the vehicle first, then the player.
  local vehicle = player.vehicle or nil
  
  if vehicle then
    -- TODO
    
    vehicle:teleport(closest_position, surface,
      raise_teleported and raise_teleported == true or false)
    teleport_AOK = player:teleport(closest_position, surface,
      raise_teleported and raise_teleported == true or false)
  else
    teleport_AOK = player:teleport(closest_position, surface,
      raise_teleported and raise_teleported == true or false)
  end

  -- A succeful teleport!
  if teleport_AOK then return Constants.enums.return_state.SUCCESS end

  -- Fallback error
  return "We were unable to perform the teleport due to unforeseen circumstances"
end

return Tag
