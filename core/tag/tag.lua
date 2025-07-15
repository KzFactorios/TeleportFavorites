--[[
core/tag/tag.lua
TeleportFavorites Factorio Mod
-----------------------------
Tag model and utilities for managing teleportation tags, chart tags, and player favorites.

- Encapsulates tag data (GPS, chart_tag, faved_by_players) and provides methods for favorite management, ownership checks, and tag rehoming.
- Handles robust teleportation logic with error messaging, including vehicle and collision checks.
- Provides helpers for moving, destroying, and unlinking tags and their associated chart tags.
- All tag-related state and operations are centralized here for maintainability and DRYness.
]]

local GPSUtils = require("core.utils.gps_utils")
local tag_destroy_helper = require("core.tag.tag_destroy_helper")
local Cache = require("core.cache.cache")
local ErrorHandler = require("core.utils.error_handler")
local LocaleUtils = require("core.utils.locale_utils")
local TeleportStrategies = require("core.utils.teleport_strategy")
local TeleportUtils = TeleportStrategies.TeleportUtils
local ChartTagUtils = require("core.utils.chart_tag_utils")
local PositionUtils = require("core.utils.position_utils")

local ChartTagSpecBuilder = require("core.utils.chart_tag_spec_builder")


---@class Tag
---@field gps string # The GPS string (serves as the index)
---@field chart_tag LuaCustomChartTag? # Cached chart tag (private, can be nil)
---@field faved_by_players uint[] # Array of player indices who have favorited this tag
local Tag = {}
Tag.__index = Tag

local destroying_tags = setmetatable({}, { __mode = "k" })
local destroying_chart_tags = setmetatable({}, { __mode = "k" })

--- Create a new Tag instance.
---@param gps string
---@param faved_by_players uint[]|nil
---@return Tag
function Tag.new(gps, faved_by_players)
  return setmetatable({ gps = gps, faved_by_players = faved_by_players or {} }, Tag)
end

--- Teleport a player to a position on a surface, with robust checks and error messaging.
--- Now uses Strategy Pattern for different teleportation scenarios.
---@param player LuaPlayer
---@param gps string
---@param context TeleportContext? Optional context for strategy selection
---@return string|integer
function Tag.teleport_player_with_messaging(player, gps, context)
  ErrorHandler.debug_log("Starting strategy-based teleportation", {
    player_name = player and player.name,
    gps = gps,
    context = context
  })
  local result = TeleportUtils.teleport_to_gps(player, gps, context, true)
  if type(result) == "boolean" then
    if result then
      return "success"
    else
      return "teleport_failed"
    end
  elseif type(result) == "string" or type(result) == "number" then
    return result
  else
    return "teleport_failed"
  end
end

--- Collect all favorites from all players that reference the given GPS
---@param current_gps string
---@return table[]
local function collect_linked_favorites(current_gps)
  ErrorHandler.debug_log("Collecting linked favorites", { current_gps = current_gps })

  local all_fave_tags = {}
  local game_players = (_G.game and _G.game.players) or {}
  for _, a_player in pairs(game_players) do
    local pfaves = Cache.get_player_favorites(a_player)
    for _, favorite in pairs(pfaves) do
      if favorite.gps == current_gps then
        table.insert(all_fave_tags, favorite)
      end
    end
  end

  ErrorHandler.debug_log("Found linked favorites", { count = #all_fave_tags })
  return all_fave_tags
end

--- Create and validate a new chart tag at the destination
---@param player LuaPlayer
---@param destination_pos MapPosition
---@param chart_tag LuaCustomChartTag
---@return LuaCustomChartTag?, string?
local function create_new_chart_tag(player, destination_pos, chart_tag)  ErrorHandler.debug_log("Creating new chart tag", { destination_pos = destination_pos })  
  local chart_tag_spec = ChartTagSpecBuilder.build(destination_pos, chart_tag, player, nil, true)
    -- Create chart tag using our safe wrapper  
  local new_chart_tag = ChartTagUtils.safe_add_chart_tag(player.force, player.surface, chart_tag_spec, player)
  if not new_chart_tag or not new_chart_tag.valid then
    ErrorHandler.debug_log("Chart tag creation failed")
    return nil, LocaleUtils.get_error_string(nil, "destination_not_available")
  end

  ErrorHandler.debug_log("Chart tag created successfully")
  return new_chart_tag, nil
end

--- Update all favorites to use the new GPS coordinates
---@param all_fave_tags table[]
---@param destination_gps string
local function update_favorites_gps(all_fave_tags, destination_gps)
  for _, favorite in pairs(all_fave_tags) do
    favorite.gps = destination_gps
  end
end

--- Clean up the old chart tag
---@param chart_tag LuaCustomChartTag?
local function cleanup_old_chart_tag(chart_tag)
  if chart_tag and chart_tag.valid then
    ErrorHandler.debug_log("Destroying old chart tag")
    chart_tag.destroy()
    ErrorHandler.debug_log("Old chart tag destroyed successfully")
  else
    ErrorHandler.debug_log("Chart tag cleanup skipped: Invalid or missing chart tag")
  end
end

return Tag
