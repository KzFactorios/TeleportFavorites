local Constants = require("constants")
local Favorite = require("core.favorite.favorite")
local Settings = require("settings")
local Helpers = require("core.utils.helpers")
local GPS = require("core.gps.gps")
local tag_destroy_helper = require("core.tag.tag_destroy_helper")
local Lookups = require("core.cache.lookups")
-- Lazy require to break circular dependency with core.cache.cache
local function get_cache()
  return require("core.cache.cache")
end

---@class Tag
---@field gps string # The GPS string (serves as the index)
---@field chart_tag LuaCustomChartTag # Cached chart tag (private)
---@field faved_by_players uint[] # Array of player indices who have favorited this tag

local Tag = {}
Tag.__index = Tag

-- Guard table to prevent recursive destruction
local destroying_tags = setmetatable({}, { __mode = "k" })
local destroying_chart_tags = setmetatable({}, { __mode = "k" })

--- Constructor for Tag
---@param gps string
---@param faved_by_players uint[]|nil
---@return Tag
function Tag.new(gps, faved_by_players)
  local self = setmetatable({}, Tag)
  self.gps = gps
  self.faved_by_players = faved_by_players or {}
  return self
end

--- Get the related LuaCustomChartTag, retrieving and caching it by gps
---@return LuaCustomChartTag|nil
function Tag:get_chart_tag()
  if not self.chart_tag then
    self.chart_tag = Lookups.get_chart_tag_by_gps(self.gps)
  end
  return self.chart_tag
end

--- @param player LuaPlayer
--- @return boolean
function Tag:is_player_favorite(player)
  if not self or not self.faved_by_players then return false end
  for _, idx in ipairs(self.faved_by_players) do
    if idx == player.index then return true end
  end
  return false
end

--- @param player LuaPlayer
--- @return boolean
function Tag:is_owner(player)
  if not self.chart_tag then
    return false
  end
  return self.chart_tag.last_user ~= nil and self.chart_tag.last_user == player.name
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
  -- These checks are in align_position, but the return message here target teleporting
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

  local err_msg, aligned_position = GPS.normalize_landing_position(player, position, surface or player.surface or 1)
  if err_msg ~= nil and Helpers.trim(tostring(err_msg)) ~= "" then
    return tostring(err_msg)
  end

  if aligned_position then
    local teleport_AOK = false
    -- Vehicle teleportation: In Factorio, teleporting a vehicle does NOT move the player with it automatically.
    -- To ensure the player stays inside the vehicle, you must teleport the vehicle first, and the player immediately thereafter.
    ---@diagnostic disable-next-line
    if player.driving and player.vehicle then
      ---@diagnostic disable-next-line
      if player.riding_state and player.riding_state ~= defines.riding.acceleration.nothing then
        -- check state of vehicle - cannot teleport from a moving vehicle
        return "Are you crazy? Trying to teleport while driving is strictly prohibited."
      end
      player.vehicle:teleport(aligned_position, surface,
        raise_teleported and raise_teleported == true or false)
      teleport_AOK = player:teleport(aligned_position, surface,
        raise_teleported and raise_teleported == true or false)
    else
      teleport_AOK = player:teleport(aligned_position, surface,
        raise_teleported and raise_teleported == true or false)
    end

    -- A succeful teleport!
    if teleport_AOK then return Constants.enums.return_state.SUCCESS end
  end

  -- Fallback error
  return "We were unable to perform the teleport due to unforeseen circumstances"
end

--- This handles moving a chart_tag to a new location. chart_tag.Position is read-only,
--- so to move a tag we have to create a new tag and delete the old one
---@param player LuaPlayer
---@param destination_gps string
---@returns string, LuaCustomChartTag?
function Tag:rehome_chart_tag(player, destination_gps)
  -- get the gps from the local current_gps = self.gps
  -- get the aligned position of the destination_gps
  -- aligned_gps == map_position_t0_gps(aligned_position)
  -- if current_gps == aligned_gps then return self end

  -- loop thru the game.players and for any favorite that matches the current_gps save any found_tag to a collection all_fave_tags
  -- create a new chart_tag_spec for the new location - copy the matching info from tag.get_chart_tag.
  --    Use gps_to_map_position(aligned_gps) for the chart_tag_spec.position
  -- local new_chart_tag = player.force.add_chart_tag(surface, chart_tag_spec)
  -- loop thru the all_fave_tags and if the favorite.gps == current_gps then update the favorite.gps to the aligned_gps
  -- if a valid tag was created then get a ref old_chart_tag to the tag.chart_tag. if it wan;t created or isn't valid then return an error
  -- update self.gps to aligned_gps and the chart_tag to the newly created chart_tag
  -- destroy the old_chart_tag
  -- return the tag.chart_tag

  -- Defensive: self must be a Tag instance
  if not self or type(self) ~= "table" or not self.gps then
    return "Invalid tag object"
  end

  local current_gps = self.gps
  local msg, aligned_position = GPS.normalize_landing_position(player, destination_gps, player.surface)
  if msg ~= nil and Helpers.trim(tostring(msg)) ~= "" then
    return msg
  end
  if aligned_position == nil then
    return "[TeleportFavorites] Could not find a valid location within range"
  end

  local surface_index = player.surface and player.surface.index or 1
  local aligned_gps = GPS.gps_from_map_position(aligned_position, surface_index)
  local old_chart_tag = self:get_chart_tag()
  if current_gps == aligned_gps and old_chart_tag and old_chart_tag.valid == true then
    return nil, old_chart_tag
  end

  -- Find all favorite tags matching current_gps for all players
  local all_fave_tags = {}
  ---@diagnostic disable-next-line: undefined-global
  for _, other_player in pairs(game.players) do
    local favorites = get_cache().get_player_favorites(other_player)
    if favorites and type(favorites) == "table" then
      for _, favorite in pairs(favorites) do
        if favorite.gps == current_gps then
          table.insert(all_fave_tags, favorite)
        end
      end
    end
  end

  -- Build new chart_tag_spec by copying info from old_chart_tag
  local chart_tag_spec = {
    position = aligned_position,
    icon = old_chart_tag and old_chart_tag.icon or {},
    text = old_chart_tag and old_chart_tag.text or "",
    last_user = old_chart_tag and old_chart_tag.last_user or player.name
  }

  -- Create the new chart tag
  local surface = player.surface
  local new_chart_tag = player.force:add_chart_tag(surface, chart_tag_spec)
  if not new_chart_tag or not new_chart_tag.valid then
    return "Failed to create new chart tag"
  end

  -- Update all favorite tags to use the new gps
  for _, favorite in pairs(all_fave_tags) do
    favorite.gps = aligned_gps
  end

  -- Update self.gps and self.chart_tag
  self.gps = aligned_gps
  self.chart_tag = new_chart_tag

  -- Destroy the old chart tag
  if old_chart_tag and old_chart_tag.valid then
    tag_destroy_helper.destroy_tag_and_chart_tag(nil, old_chart_tag)
  end
  return nil, self.chart_tag
end

--- Unlink and destroy a tag and its associated chart_tag, and remove from all collections.
--- Order: remove all player favorites, destroy chart_tag, remove tag from storage.
---@param tag Tag
function Tag.unlink_and_destroy(tag)
  if not tag or type(tag) ~= "table" or not tag.gps then return end
  local chart_tag = tag.chart_tag
  tag_destroy_helper.destroy_tag_and_chart_tag(tag, chart_tag)
end

return Tag
