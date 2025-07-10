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
    Cache.init()
  end
end

---@class ChartTagOwnershipManager
local ChartTagOwnershipManager = {}

--- Reset ownership for all chart tags owned by a specific player
---@param player_name string Name of the player whose ownership should be reset
---@return number count Number of chart tags that had ownership reset
function ChartTagOwnershipManager.reset_ownership_for_player(player_name)
  if not player_name or player_name == "" then
    ErrorHandler.warn_log("Cannot reset ownership: invalid player name")
    return 0
  end
  ErrorHandler.debug_log("Starting ownership reset for player", {
    player_name = player_name
  })
  local reset_count = 0
  local affected_surfaces = {}

  -- Ensure Cache is initialized before accessing Lookups
  ensure_cache_initialized()

  -- Use our lookup cache to find chart tags
  for _, surface in pairs(game.surfaces) do
    if surface and surface.valid then
      local surface_cache = Cache.Lookups.get_chart_tag_cache(surface.index)

      for _, chart_tag in pairs(surface_cache or {}) do
        if chart_tag and chart_tag.valid and chart_tag.last_user and chart_tag.last_user.name == player_name then
          ---@diagnostic disable-next-line: assign-type-mismatch
          chart_tag.last_user = ""
          reset_count = reset_count + 1
          affected_surfaces[surface.index] = true

          ErrorHandler.debug_log("Reset chart tag ownership", {
            surface = surface.name,
            position = chart_tag.position,
            old_owner = player_name,
            text = chart_tag.text or ""
          })
        end
      end
    end
  end

  -- Invalidate lookup caches for affected surfaces
  for surface_index, _ in pairs(affected_surfaces) do
    Cache.Lookups.invalidate_surface_chart_tags(surface_index)
    ErrorHandler.debug_log("Invalidated chart tag cache for surface", {
      surface_index = surface_index
    })
  end
  ErrorHandler.debug_log("Ownership reset completed", {
    player_name = player_name,
    reset_count = reset_count,
    affected_surfaces_count = CollectionUtils.table_count(affected_surfaces)
  })

  return reset_count
end

--- Handle player leaving the game - reset their chart tag ownership
---@param event table Player left game event
function ChartTagOwnershipManager.on_player_left_game(event)
  local player = game.get_player(event.player_index)
  if not player then
    ErrorHandler.warn_log("Cannot handle player left: invalid player index", {
      player_index = event.player_index
    })
    return
  end

  ErrorHandler.debug_log("Player left game - checking chart tag ownership", {
    player_name = player_name,
    player_index = event.player_index
  })
  local reset_count = 0
  local reason = event.reason or ""
  if reason == defines.disconnect_reason.switching_servers
      or reason == defines.disconnect_reason.kicked_and_deleted
      or reason == defines.disconnect_reason.banned then
    -- Reset ownership for all chart tags owned by this player
    ---@diagnostic disable-next-line: assign-type-mismatch
    reset_count = ChartTagOwnershipManager.reset_ownership_for_player(player_name)
  end

  --[[ These are the other reasons
   defines.disconnect_reason.afk	
  defines.disconnect_reason.quit	
  defines.disconnect_reason.dropped	
  defines.disconnect_reason.reconnect	
  defines.disconnect_reason.wrong_input	
  defines.disconnect_reason.desync_limit_reached	
  defines.disconnect_reason.cannot_keep_up	
  defines.disconnect_reason.kicked
  ]]

  if reset_count > 0 then
    ErrorHandler.debug_log("Reset chart tag ownership due to player leaving", {
      player_name = player_name,
      reset_count = reset_count
    })
  end
end

--- Handle player being removed from the game - reset their chart tag ownership
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
  ErrorHandler.debug_log("Player removed - checking chart tag ownership", {
    player_name = player_name,
    player_index = event.player_index
  })
  -- Reset ownership for all chart tags owned by this player
  ---@diagnostic disable-next-line: assign-type-mismatch
  local reset_count = ChartTagOwnershipManager.reset_ownership_for_player(player_name)

  if reset_count > 0 then
    ErrorHandler.debug_log("Reset chart tag ownership due to player removal", {
      player_name = player_name,
      reset_count = reset_count
    })
  end
end

return ChartTagOwnershipManager
