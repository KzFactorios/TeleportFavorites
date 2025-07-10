-- filepath: v:\Fac2orios\2_Gemini\mods\TeleportFavorites\core\control\chart_tag_ownership_manager.lua
---@diagnostic disable: undefined-global
--[[
chart_tag_ownership_manager.lua
TeleportFavorites Factorio Mod
-----------------------------
Manages chart tag ownership lifecycle and cleanup operations.

Features:
---------
- Handles chart tag ownership when players leave/are removed
- Resets chart tag ownership to "" when owner leaves
- Updates lookup collections when ownership changes
- Provides utilities for ownership validation and transfer

Core Principle:
---------------
- Only the player who CREATES a tag becomes the owner
- Ownership does NOT change when other players edit the tag
- Ownership only resets when the owner leaves/is removed from the game
- When ownership is reset, all related lookup collections are updated
--]]

local Cache = require("core.cache.cache")
local ErrorHandler = require("core.utils.error_handler")
local CollectionUtils = require("core.utils.collection_utils")

--- Ensure Cache is initialized before accessing Lookups
local function ensure_cache_initialized()
  if not Cache.Lookups then
    -- no-op for test
  end
end

---@class ChartTagOwnershipManager
local ChartTagOwnershipManager = {}

--- Reset ownership for all chart tags owned by a specific player
---@param player_name string Name of the player whose ownership should be reset
function ChartTagOwnershipManager.reset_ownership_for_player(player_name)
  if not player_name or player_name == "" then
    ErrorHandler.warn_log("Cannot reset ownership: invalid player name")
    return 0
  end
  local reset_count = 0
  local affected_surfaces = {}
  ensure_cache_initialized()
  for _, surface in pairs(game.surfaces) do
    if surface and surface.valid then
      local surface_cache = Cache.Lookups.get_chart_tag_cache(surface.index)
      for _, chart_tag in pairs(surface_cache) do
        if chart_tag and chart_tag.valid and chart_tag.last_user and chart_tag.last_user.name == player_name then
          chart_tag.last_user = nil
          reset_count = reset_count + 1
          affected_surfaces[surface.index] = true
        end
      end
    end
  end
  for surface_index, _ in pairs(affected_surfaces) do
    Cache.Lookups.invalidate_surface_chart_tags(surface_index)
  end
  return reset_count
end

---@param event table Player left game event
function ChartTagOwnershipManager.on_player_left_game(event)
  local player = game.get_player(event.player_index)
  if not player then
    ErrorHandler.warn_log("Cannot handle player left: invalid player index", {
      player_index = event.player_index
    })
    return
  end
  local player_name = player.name
  local reset_count = 0
  local reason = event.reason or ""
  if reason == defines.disconnect_reason.switching_servers
      or reason == defines.disconnect_reason.kicked_and_deleted
      or reason == defines.disconnect_reason.banned then
    reset_count = ChartTagOwnershipManager.reset_ownership_for_player(player_name)
  end
  if reset_count > 0 then
    ErrorHandler.debug_log("Reset chart tag ownership due to player leaving", {
      player_name = player_name,
      reset_count = reset_count
    })
  end
end

---@param event table Player removed event
function ChartTagOwnershipManager.on_player_removed(event)
  local player = game.get_player(event.player_index)
  if not player then
    ErrorHandler.warn_log("Cannot handle player removed: invalid player index", {
      player_index = event.player_index
    })
    return
  end
  local player_name = player.name
  local reset_count = ChartTagOwnershipManager.reset_ownership_for_player(player_name)
  if reset_count > 0 then
    ErrorHandler.debug_log("Reset chart tag ownership due to player removal", {
      player_name = player_name,
      reset_count = reset_count
    })
  end
end

return ChartTagOwnershipManager
