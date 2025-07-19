-- core/tag/tag.lua
-- TeleportFavorites Factorio Mod
-- Tag model and utilities for managing teleportation tags, chart tags, and player favorites.

local ErrorHandler = require("core.utils.error_handler")
local TeleportStrategies = require("core.utils.teleport_strategy")
local TeleportUtils = TeleportStrategies.TeleportUtils


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

return Tag
